require("dotenv").config();

const express = require("express");
const path = require("node:path");
const { LocalStore, collections } = require("./local-store");
const { SqlStore, ValidationError } = require("./sql-store");
const { validateRecord } = require("./crud-schema");
const { tv5Error } = require("./tv5-errors");
const { executeTransaction, tv4Error, paymentMessage } = require("./transactions");
const { getTv7Snapshot } = require("./tv7-read");
const { registerSearchRoutes } = require("./search-routes");
const { registerBuildingRoutes } = require("./building-routes");

const projectRoot = path.resolve(__dirname, "..");
const port = Number(process.env.PORT || 3000);
const dataMode = process.env.DATA_MODE || "local";
const store = new LocalStore(path.join(projectRoot, "data", "local-db.json"));
const sqlStore = dataMode === "mysql" ? new SqlStore() : null;
const app = express();
registerSearchRoutes(app, sqlStore, store);

if (!["local", "mysql"].includes(dataMode)) {
  throw new Error("DATA_MODE must be either local or mysql");
}

const reportNames = ["company-cost", "daily-services", "payroll", "building-cashflow"];

app.disable("x-powered-by");
app.use(express.json({ limit: "32kb" }));
app.use((_, response, next) => {
  response.set({
    "Referrer-Policy": "same-origin",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY"
  });
  next();
});
// maxAge 0: trình duyệt kiểm tra lại file mỗi lần, tránh giữ bản giao diện cũ khi đổi phiên bản.
app.use("/assets", express.static(path.join(projectRoot, "assets"), { maxAge: 0 }));
registerBuildingRoutes(app, sqlStore);

function sendError(response, status, code, message) {
  response.status(status).json({ code, message });
}

app.get("/api/health", async (_, response) => {
  if (dataMode !== "mysql") return response.json({ status: "ok", dataMode: "local" });
  try {
    return response.json(await sqlStore.health());
  } catch (error) {
    return sendError(response, 503, error.code === "SCHEMA_MISMATCH" ? "SCHEMA_MISMATCH" : "DATABASE_UNAVAILABLE",
      error.code === "SCHEMA_MISMATCH" ? "CSDL không khớp lược đồ BCNF mới nhất của TV3." : "Không thể kết nối MySQL. Hãy kiểm tra cấu hình .env.");
  }
});

app.get("/api/tv7/distribution", async (_, response, next) => {
  try { return response.json(await getTv7Snapshot()); }
  catch (error) { return next(error); }
});

app.get("/api/lookups", async (_, response, next) => {
  try {
    if (sqlStore) return response.json(await sqlStore.lookups());
    return response.json({ buildings: [], locations: [], serviceTypes: [],
      companies: (await store.list("companies")).map((row) => ({ id: row.code, name: row.name })),
      companyEmployees: (await store.list("employees")).filter((row) => row.type === "company")
        .map((row) => ({ id: row.code, name: row.name, companyId: row.companyId })),
      offices: (await store.list("offices")).map((row) => ({ id: row.code, name: row.code, buildingId: row.buildingId })),
      managers: (await store.list("employees")).filter((row) => row.type === "building" && row.employeeType === "QUAN_LY")
        .map((row) => ({ id: row.code, name: row.name, buildingId: row.buildingId })) });
  } catch (error) { return next(error); }
});

for (const collection of collections) {
  app.get(`/api/${collection}`, async (_, response, next) => {
    try { return response.json(await (sqlStore || store).list(collection)); } catch (error) { return next(error); }
  });
  app.post(`/api/${collection}`, async (request, response, next) => {
    try {
      const record = validateRecord(collection, request.body);
      return response.status(201).json(await (sqlStore ? sqlStore.write(collection, record) : store.create(collection, record)));
    } catch (error) { return next(error); }
  });
  app.put(`/api/${collection}/:id`, async (request, response, next) => {
    try {
      const record = validateRecord(collection, request.body);
      const updated = await (sqlStore ? sqlStore.write(collection, record, request.params.id) : store.update(collection, request.params.id, record));
      return updated ? response.json(updated) : sendError(response, 404, "NOT_FOUND", "Không tìm thấy bản ghi cần sửa.");
    } catch (error) { return next(error); }
  });
  app.delete(`/api/${collection}/:id`, async (request, response, next) => {
    try { return (await (sqlStore || store).remove(collection, request.params.id)) ? response.status(204).end() : sendError(response, 404, "NOT_FOUND", "Không tìm thấy bản ghi cần xóa."); } catch (error) { return next(error); }
  });
}

for (const name of reportNames) {
  app.get(`/api/reports/${name}`, async (request, response, next) => {
    if (dataMode === "mysql") {
      try { return response.json(await sqlStore.report(name, request.query)); } catch (error) { return next(error); }
    }
    return sendError(response, 503, "REPORTS_REQUIRE_SQL",
      "Báo cáo tài chính cần MySQL với dữ liệu BCNF của TV3.");
  });
}

app.post("/api/transactions/:name", async (request, response, next) => {
  const allowed = new Set(["contract", "daily-service", "invoice", "payment", "payroll"]);
  if (!allowed.has(request.params.name)) return sendError(response, 404, "NOT_FOUND", "Không tìm thấy giao dịch.");
  if (!sqlStore) return sendError(response, 503, "TRANSACTIONS_REQUIRE_SQL", "Giao dịch TV4 cần MySQL.");
  try {
    const health = await sqlStore.health();
    if (!health.transactionsReady) return sendError(response, 503, "TRANSACTIONS_NOT_READY",
      "Cần cài bốn procedure TV4 và mười trigger TV5 trên CSDL MySQL.");
    // TV6 sửa: chỉ bật giao dịch thứ năm khi procedure thanh toán đầy đủ đã được cài.
    if (request.params.name === "payment" && !health.paymentReady)
      return sendError(response, 501, "51400", paymentMessage);
    return response.json(await executeTransaction(sqlStore, request.params.name, request.body));
  }
  catch (error) { return next(error); }
});

app.get("/", (_, response) => response.sendFile(path.join(projectRoot, "index.html")));
app.use((request, response) => sendError(response, 404, "NOT_FOUND", `Không tìm thấy ${request.method} ${request.path}`));
app.use((error, _, response, __) => {
  if (error instanceof ValidationError) return sendError(response, 422, "VALIDATION_ERROR", error.message);
  if (error.code === "SCHEMA_MISMATCH") return sendError(response, 503, "SCHEMA_MISMATCH", "CSDL không khớp lược đồ BCNF mới nhất của TV3.");
  const triggerError = tv5Error(error);
  if (triggerError) return sendError(response, 409, triggerError.code, triggerError.message);
  const transactionError = tv4Error(error);
  if (transactionError) return sendError(response, transactionError.code === "51400" ? 501 : 409,
    transactionError.code, transactionError.message);
  // Mã lỗi của MySQL (mysql2 đặt trong error.errno; SIGNAL của trigger/procedure dùng MYSQL_ERRNO 5xxxx).
  if (error.errno === 1062) return sendError(response, 409, "DUPLICATE_VALUE", "Mã hoặc mã số thuế đã tồn tại.");
  if ([1451, 1452, 3819].includes(error.errno)) return sendError(response, 409, "CONSTRAINT_VIOLATION", "Bản ghi vi phạm khóa ngoại hoặc ràng buộc dữ liệu. Kiểm tra các lựa chọn và dữ liệu liên quan.");
  if (error.errno >= 50000 && error.errno <= 59999) return sendError(response, 409, "BUSINESS_RULE", error.message);
  if ([1048, 1265, 1292, 1366, 1406].includes(error.errno)) return sendError(response, 422, "VALIDATION_ERROR", "Dữ liệu không khớp kiểu hoặc độ dài cột MySQL.");
  console.error(error);
  if (dataMode === "mysql" && ["ECONNREFUSED", "ENOTFOUND", "ETIMEDOUT", "ECONNRESET", "PROTOCOL_CONNECTION_LOST",
    "PROTOCOL_ENQUEUE_AFTER_FATAL_ERROR", "ER_ACCESS_DENIED_ERROR", "ER_BAD_DB_ERROR"].includes(error.code))
    return sendError(response, 503, "DATABASE_UNAVAILABLE", "Không thể kết nối MySQL.");
  sendError(response, 500, "INTERNAL_ERROR", "Máy chủ gặp lỗi không mong muốn.");
});

if (require.main === module) {
  const host = process.env.HOST || "0.0.0.0";
  app.listen(port, host, () => {
    console.log(`Office Chain Manager chạy tại http://${host === "0.0.0.0" ? "localhost" : host}:${port}`);
  });
}

module.exports = { app, sqlStore };
