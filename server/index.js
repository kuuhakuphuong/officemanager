require("dotenv").config();

const express = require("express");
const path = require("node:path");
const { LocalStore, collections } = require("./local-store");
const { SqlStore, ValidationError } = require("./sql-store");
const { validateRecord } = require("./crud-schema");
const { tv5Error } = require("./tv5-errors");
const { executeTransaction, tv4Error, paymentMessage } = require("./transactions");
const { getTv7Snapshot } = require("./tv7-read");

const projectRoot = path.resolve(__dirname, "..");
const port = Number(process.env.PORT || 3000);
const dataMode = process.env.DATA_MODE || "local";
const store = new LocalStore(path.join(projectRoot, "data", "local-db.json"));
const sqlStore = dataMode === "sqlserver" ? new SqlStore() : null;
const app = express();

if (!["local", "sqlserver"].includes(dataMode)) {
  throw new Error("DATA_MODE must be either local or sqlserver");
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
app.use("/assets", express.static(path.join(projectRoot, "assets"), { maxAge: "1h" }));

function sendError(response, status, code, message) {
  response.status(status).json({ code, message });
}

app.get("/api/health", async (_, response) => {
  if (dataMode !== "sqlserver") return response.json({ status: "ok", dataMode: "local" });
  try {
    return response.json(await sqlStore.health());
  } catch (error) {
    return sendError(response, 503, error.code === "SCHEMA_MISMATCH" ? "SCHEMA_MISMATCH" : "DATABASE_UNAVAILABLE",
      error.code === "SCHEMA_MISMATCH" ? "CSDL không khớp lược đồ BCNF mới nhất của TV3." : "Không thể kết nối SQL Server. Hãy kiểm tra cấu hình .env.");
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
    if (dataMode === "sqlserver") {
      try { return response.json(await sqlStore.report(name, request.query)); } catch (error) { return next(error); }
    }
    return sendError(response, 503, "REPORTS_REQUIRE_SQL",
      "Báo cáo tài chính cần SQL Server với dữ liệu BCNF của TV3.");
  });
}

app.post("/api/transactions/:name", async (request, response, next) => {
  const allowed = new Set(["contract", "daily-service", "invoice", "payment", "payroll"]);
  if (!allowed.has(request.params.name)) return sendError(response, 404, "NOT_FOUND", "Không tìm thấy giao dịch.");
  if (!sqlStore) return sendError(response, 503, "TRANSACTIONS_REQUIRE_SQL", "Giao dịch TV4 cần SQL Server.");
  try {
    const health = await sqlStore.health();
    if (!health.transactionsReady) return sendError(response, 503, "TRANSACTIONS_NOT_READY",
      "Cần cài hai table type, bốn procedure TV4 và sáu trigger TV5 trên CSDL SQL Server.");
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
  if ([2601, 2627].includes(error.number)) return sendError(response, 409, "DUPLICATE_VALUE", "Mã hoặc mã số thuế đã tồn tại.");
  if (error.number === 547) return sendError(response, 409, "CONSTRAINT_VIOLATION", "Bản ghi vi phạm khóa ngoại hoặc ràng buộc dữ liệu. Kiểm tra các lựa chọn và dữ liệu liên quan.");
  if (error.number >= 50000 && error.number <= 59999) return sendError(response, 409, "BUSINESS_RULE", error.message);
  if ([515, 2628, 8152].includes(error.number)) return sendError(response, 422, "VALIDATION_ERROR", "Dữ liệu không khớp kiểu hoặc độ dài cột SQL.");
  console.error(error);
  if (dataMode === "sqlserver" && ["ESOCKET", "ECONNCLOSED", "ELOGIN", "ETIMEOUT", "ENOTOPEN", "EINSTLOOKUP"].includes(error.code))
    return sendError(response, 503, "DATABASE_UNAVAILABLE", "Không thể kết nối SQL Server.");
  sendError(response, 500, "INTERNAL_ERROR", "Máy chủ gặp lỗi không mong muốn.");
});

if (require.main === module) {
  const host = process.env.HOST || "0.0.0.0";
  app.listen(port, host, () => {
    console.log(`Office Chain Manager chạy tại http://${host === "0.0.0.0" ? "localhost" : host}:${port}`);
  });
}

module.exports = { app, sqlStore };
