const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { MongoClient } = require("mongodb");
const { MongoStore } = require("../server/mongo/store");
const { MongoConnection } = require("../server/mongo/connection");
const { runTransaction } = require("../server/mongo/transactions");
const { load } = require("../database/seed/seed");

// Chạy: RUN_MONGO_TESTS=1 MONGO_URI=mongodb://admin:...@127.0.0.1:27017/?authSource=admin node --test test/mongo-integration.test.js
// Tạo CSDL tạm (không shard) để nạp seed, chạy nghiệp vụ, rồi xóa.
const enabled = process.env.RUN_MONGO_TESTS === "1";

test("MongoDB stack: seed, TV4 transactions (rules and happy path), reports on an isolated database", { skip: !enabled }, async () => {
  const uri = process.env.MONGO_URI;
  const name = `QuanLyToaNhaTest_${crypto.randomBytes(4).toString("hex")}`;
  const connection = new MongoConnection({ uri, database: name });
  const store = new MongoStore(connection);
  try {
    await load(uri, name);
    await store.connect();

    const health = await store.health();
    assert.equal(health.transactionsReady, true);
    assert.equal((await store.list("companies")).length, 6);

    // Hợp đồng chồng lịch với VP01 (đã thuê từ 2026-07-01): bị chặn (51106) trong kỳ chưa lập hóa đơn.
    const overlap = await runTransaction(connection, "contract", { companyId: "CT02", buildingId: "TN01",
      startDate: "2026-12-01", endDate: "2026-12-31", officeIds: ["VP01"] }).catch((e) => e);
    assert.equal(overlap.errno, 51106);

    // Hóa đơn tháng 9/2026 đã có sẵn: không lập trùng (51304).
    const duplicate = await runTransaction(connection, "invoice", { buildingId: "TN01", month: 9, year: 2026 }).catch((e) => e);
    assert.equal(duplicate.errno, 51304);

    // Hóa đơn tháng 8/2026 đã thanh toán trong seed: thanh toán lại bị chặn (51403).
    const paid = await connection.db().collection("hoa_don_thang").findOne({ thang: 8, trangThai: "DA_THANH_TOAN" });
    const again = await runTransaction(connection, "payment", { invoiceId: paid.maHoaDon, amount: paid.tongTien,
      paymentDate: "2026-09-10", collector: "Test" }).catch((e) => e);
    assert.equal(again.errno, 51403);

    // Nhân viên không tồn tại: ghi nhật ký bị từ chối cả lô (51202).
    const badUse = await runTransaction(connection, "daily-service", { items: [
      { employeeId: "NVKHONGCO", serviceId: "AN01", useDate: "2026-08-03", quantity: 1 }] }).catch((e) => e);
    assert.equal(badUse.errno, 51202);

    // Ca hợp lệ: ghi nhật ký ngày 2026-10-01 cho NVCT001 (đăng ký và hợp đồng hợp lệ).
    const use = await runTransaction(connection, "daily-service", { items: [
      { employeeId: "NVCT001", serviceId: "AN01", useDate: "2026-10-01", quantity: 2 }] });
    assert.equal(use.rows[0].SoDongDaGhi, 1);

    // Lập hóa đơn tháng 10/2026 rồi thanh toán đủ một lần.
    const [invoice] = (await runTransaction(connection, "invoice", { buildingId: "TN01", month: 10, year: 2026 })).rows;
    assert.ok(invoice.TongTien > 0);
    const settled = await runTransaction(connection, "payment", { invoiceId: invoice.MaHoaDon,
      amount: invoice.TongTien, paymentDate: new Date().toISOString().slice(0, 10), collector: "Test" });
    assert.equal(settled.rows[0].TrangThai, "DA_THANH_TOAN");

    const cashflow = await store.report("building-cashflow", {});
    assert.ok(cashflow.summary.totalIncome > 0);
    assert.ok(cashflow.summary.totalExpense > 0);
  } finally {
    await store.close();
    const client = new MongoClient(uri);
    await client.connect();
    await client.db(name).dropDatabase();
    await client.close();
  }
});
