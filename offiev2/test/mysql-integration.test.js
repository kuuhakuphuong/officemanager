const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const mysql = require("mysql2/promise");
const { SqlStore, mysqlConfig } = require("../server/sql-store");
const { executeTransaction, tv4Error } = require("../server/transactions");
const { splitSql } = require("../database/tools/mysql-script");

const root = path.resolve(__dirname, "..");
const enabled = process.env.RUN_MYSQL_TESTS === "1";
const files = [
  "database/schema/01_CreateSchema_TV3_NguyenThiLanAnh.sql",
  "database/schema/02_InsertSeedData_TV3_NguyenThiLanAnh.sql",
  "database/schema/03_Validate_TV3_NguyenThiLanAnh.sql",
  "database/triggers/05_Phan5_Triggers_TV5_KhucTuanAnh.sql",
  "database/transactions/00_TaoKieuDuLieu_TV4_VuTrungHieu.sql",
  "database/transactions/02_KiemTraTuongThich_TV4_VuTrungHieu.sql",
  "database/transactions/03_Transactions_TV4_VuTrungHieu.sql"
];

// Chạy script SQL trên một database tạm (tên QLToaNha_BCNF được thay bằng tên test).
async function runFile(connection, file, database) {
  const text = fs.readFileSync(path.join(root, file), "utf8").replaceAll("QLToaNha_BCNF", database);
  for (const statement of splitSql(text)) await connection.query(statement);
}

// Chạy: RUN_MYSQL_TESTS=1 DB_SERVER=localhost DB_PORT=3306 DB_USER=root DB_PASSWORD=... node --test test/mysql-integration.test.js
test("MySQL stack: schema, triggers, TV4 transactions and reports on an isolated database", { skip: !enabled }, async () => {
  const name = `QLToaNha_Test_${crypto.randomBytes(4).toString("hex")}`;
  const config = mysqlConfig();
  const admin = await mysql.createConnection({ ...config, database: undefined });
  const store = new SqlStore({ ...config, database: name });
  try {
    for (const file of files) await runFile(admin, file, name);

    const health = await store.health();
    assert.equal(health.transactionsReady, true);
    assert.equal(health.paymentReady, true);
    assert.equal((await store.list("companies")).length, 6);

    // Hợp đồng chồng lịch với HD01 (VP01 thuê 2026-07-01..2027-06-30) trong kỳ chưa lập hóa đơn: bị chặn (51106).
    const overlap = await executeTransaction(store, "contract", { companyId: "CT02", buildingId: "TN01",
      startDate: "2026-12-01", endDate: "2026-12-31", officeIds: ["VP01"] }).catch((error) => error);
    assert.equal(tv4Error(overlap)?.code, "51106");

    // Hóa đơn tháng 9/2026 đã có sẵn từ seed: không lập trùng (51304).
    const duplicate = await executeTransaction(store, "invoice", { buildingId: "TN01", month: 9, year: 2026 })
      .catch((error) => error);
    assert.equal(tv4Error(duplicate)?.code, "51304");

    // Hóa đơn tháng 8/2026 đã thanh toán trong seed: thanh toán lại phải bị chặn (51403).
    const [paid] = await store.query("SELECT MaHoaDon AS id FROM HoaDonThang WHERE Thang = 8 AND TrangThai = 'DA_THANH_TOAN' LIMIT 1");
    const again = await executeTransaction(store, "payment", { invoiceId: paid.id, amount: 1,
      paymentDate: "2026-09-10", collector: "Test" }).catch((error) => error);
    assert.equal(tv4Error(again)?.code, "51403");

    // Nhân viên không tồn tại: ghi nhật ký bị từ chối cả lô (51202).
    const badUse = await executeTransaction(store, "daily-service", { items: [
      { employeeId: "NVKHONGCO", serviceId: "AN01", useDate: "2026-08-03", quantity: 1 }] }).catch((error) => error);
    assert.equal(tv4Error(badUse)?.code, "51202");

    // Ca hợp lệ: ghi nhật ký ngày 2026-10-01 (sau dữ liệu seed) cho NVCT001 dùng AN01 (đăng ký, hợp đồng hợp lệ).
    const use = await executeTransaction(store, "daily-service", { items: [
      { employeeId: "NVCT001", serviceId: "AN01", useDate: "2026-10-01", quantity: 2 }] });
    assert.equal(use.rows[0].SoDongDaGhi, 1);

    // Lập hóa đơn tháng 10/2026 từ nhật ký vừa ghi, rồi thanh toán đủ một lần.
    const [invoice] = (await executeTransaction(store, "invoice", { buildingId: "TN01", month: 10, year: 2026 })).rows;
    assert.ok(Number(invoice.TongTien) > 0);
    const [today] = await store.query("SELECT DATE_FORMAT(CURDATE(), '%Y-%m-%d') AS d");
    const settled = await executeTransaction(store, "payment", { invoiceId: invoice.MaHoaDon,
      amount: Number(invoice.TongTien), paymentDate: today.d, collector: "Test" });
    assert.equal(settled.rows[0].TrangThai, "DA_THANH_TOAN");

    // Báo cáo dòng tiền đọc được dữ liệu seed (thu từ hóa đơn đã thanh toán, chi phí, lương).
    const cashflow = await store.report("building-cashflow", {});
    assert.ok(cashflow.summary.totalIncome > 0);
    assert.ok(cashflow.summary.totalExpense > 0);
  } finally {
    await store.close();
    await admin.query(`DROP DATABASE IF EXISTS \`${name}\``);
    await admin.end();
  }
});
