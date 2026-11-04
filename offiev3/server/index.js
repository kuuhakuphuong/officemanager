require("dotenv").config();

const express = require("express");
const path = require("node:path");
const { LocalStore, collections } = require("./local-store");
const { MongoStore, reportFilters } = require("./mongo/store");
const { MongoConnection, mongoConfig } = require("./mongo/connection");
const { runTransaction } = require("./mongo/transactions");
const { validateRecord } = require("./crud-schema");
const { validateTransaction, transactionNames } = require("./validation");
const { ValidationError } = require("./errors");
const { filterRows } = require("../assets/search");
const { registerSearchRoutes } = require("./search-routes");
const { registerBuildingRoutes } = require("./building-routes");

const projectRoot = path.resolve(__dirname, "..");
const port = Number(process.env.PORT || 3000);
const dataMode = process.env.DATA_MODE || "local";
if (!["local", "mongo"].includes(dataMode)) {
  throw new Error("DATA_MODE must be either local or mongo");
}
const store = new LocalStore(path.join(projectRoot, "data", "local-db.json"));
const mongoStore = dataMode === "mongo" ? new MongoStore(new MongoConnection(mongoConfig())) : null;
const app = express();
registerSearchRoutes(app, mongoStore, store);

const reportNames = ["company-cost", "daily-services", "payroll", "building-cashflow"];

// Kết nối MongoDB lười (lần đầu dùng) và dùng lại cho mọi yêu cầu.
async function mongo() {
  await mongoStore.connect();
  return mongoStore;
}

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
registerBuildingRoutes(app, mongoStore);

function sendError(response, status, code, message) {
  response.status(status).json({ code, message });
}

app.get("/api/health", async (_, response, next) => {
  if (dataMode !== "mongo") return response.json({ status: "ok", dataMode: "local" });
  try {
    return response.json(await (await mongo()).health());
  } catch (error) {
    return next(error);
  }
});

// Trạng thái cụm: shard, zone và số bản ghi mỗi shard (thay cho trang đối soát TV7 của bản MySQL).
app.get("/api/cluster/status", async (_, response, next) => {
  if (dataMode !== "mongo") return sendError(response, 503, "CLUSTER_REQUIRE_MONGO", "Trạng thái cụm cần chế độ mongo.");
  try { return response.json(await (await mongo()).clusterStatus()); } catch (error) { return next(error); }
});

app.get("/api/lookups", async (_, response, next) => {
  try {
    if (mongoStore) return response.json(await (await mongo()).lookups());
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
  app.get(`/api/${collection}`, async (request, response, next) => {
    try {
      // Lọc trong DB cho các điều kiện bằng nhau (có chỉ mục); phần còn lại lọc trong bộ nhớ.
      const rows = await (mongoStore ? (await mongo()).list(collection, request.query) : store.list(collection));
      return response.json(filterRows(collection, rows, request.query));
    } catch (error) { return next(error); }
  });
  app.post(`/api/${collection}`, async (request, response, next) => {
    try {
      const record = validateRecord(collection, request.body);
      return response.status(201).json(await (mongoStore ? (await mongo()).write(collection, record) : store.create(collection, record)));
    } catch (error) { return next(error); }
  });
  app.put(`/api/${collection}/:id`, async (request, response, next) => {
    try {
      const record = validateRecord(collection, request.body);
      const updated = await (mongoStore ? (await mongo()).write(collection, record, request.params.id) : store.update(collection, request.params.id, record));
      return updated ? response.json(updated) : sendError(response, 404, "NOT_FOUND", "Không tìm thấy bản ghi cần sửa.");
    } catch (error) { return next(error); }
  });
  app.delete(`/api/${collection}/:id`, async (request, response, next) => {
    try {
      const removed = await (mongoStore ? (await mongo()).remove(collection, request.params.id) : store.remove(collection, request.params.id));
      return removed ? response.status(204).end() : sendError(response, 404, "NOT_FOUND", "Không tìm thấy bản ghi cần xóa.");
    } catch (error) { return next(error); }
  });
}

for (const name of reportNames) {
  app.get(`/api/reports/${name}`, async (request, response, next) => {
    if (dataMode === "mongo") {
      try { return response.json(await (await mongo()).report(name, request.query)); } catch (error) { return next(error); }
    }
    return sendError(response, 503, "REPORTS_REQUIRE_MONGO",
      "Báo cáo tài chính cần MongoDB với dữ liệu tòa nhà của TV3.");
  });
}

app.post("/api/transactions/:name", async (request, response, next) => {
  if (!transactionNames.includes(request.params.name)) return sendError(response, 404, "NOT_FOUND", "Không tìm thấy giao dịch.");
  if (!mongoStore) return sendError(response, 503, "TRANSACTIONS_REQUIRE_MONGO", "Giao dịch TV4 cần MongoDB.");
  try {
    const body = validateTransaction(request.params.name, request.body);
    const connection = (await mongo()).connection;
    return response.json(await runTransaction(connection, request.params.name, body));
  } catch (error) { return next(error); }
});

app.get("/", (_, response) => response.sendFile(path.join(projectRoot, "index.html")));
app.use((request, response) => sendError(response, 404, "NOT_FOUND", `Không tìm thấy ${request.method} ${request.path}`));
app.use((error, _, response, __) => {
  if (error instanceof ValidationError) return sendError(response, 422, "VALIDATION_ERROR", error.message);
  if (error.code === "SCHEMA_MISMATCH") return sendError(response, 503, "SCHEMA_MISMATCH", "CSDL không khớp thiết kế MongoDB mới nhất.");
  // Mã nghiệp vụ TV4 (51xxx) và TV5 (55xxx) giữ nguyên như bản MySQL.
  if (error.errno >= 51000 && error.errno <= 51999) return sendError(response, 409, String(error.errno), error.message);
  if (error.errno >= 55000 && error.errno <= 55999) return sendError(response, 409, String(error.errno), error.message);
  // Lỗi MongoDB: trùng khóa, xung đột giao dịch, mất kết nối.
  if (error.code === 11000 || error.errno === 11000) return sendError(response, 409, "DUPLICATE_VALUE", "Mã đã tồn tại trong hệ thống.");
  if (error.hasErrorLabel?.("TransientTransactionError") || error.code === 112 || error.code === 251) {
    return sendError(response, 409, "TRANSACTION_CONFLICT", "Giao dịch xung đột với một thao tác khác. Hãy thử lại.");
  }
  console.error(error);
  if (dataMode === "mongo" && (error.name === "MongoServerSelectionError" || error.name === "MongoNetworkError"))
    return sendError(response, 503, "DATABASE_UNAVAILABLE", "Không thể kết nối MongoDB.");
  sendError(response, 500, "INTERNAL_ERROR", "Máy chủ gặp lỗi không mong muốn.");
});

if (require.main === module) {
  const host = process.env.HOST || "0.0.0.0";
  app.listen(port, host, () => {
    console.log(`Office Chain Manager chạy tại http://${host === "0.0.0.0" ? "localhost" : host}:${port}`);
  });
}

module.exports = { app, mongoStore };
