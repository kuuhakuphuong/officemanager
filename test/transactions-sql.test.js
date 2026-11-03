const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const sql = require("mssql");
const { SqlStore, sqlConfig } = require("../server/sql-store");
const { executeTransaction, tv4Error } = require("../server/transactions");

const root = path.resolve(__dirname, "..");
const enabled = process.env.RUN_SQL_TV4_TESTS === "1";

async function runSql(pool, file, database, skip = 0) {
  const source = fs.readFileSync(path.join(root, file), "utf8").replaceAll("QLToaNha_BCNF", database);
  for (const batch of source.split(/^\s*GO\s*$/gim).slice(skip).filter((part) => part.trim()))
    await pool.request().batch(batch);
}

test("TV4 web adapter runs against TV3 schema with TV5 triggers on an isolated database", { skip: !enabled }, async (t) => {
  require("dotenv").config({ path: path.join(root, ".env") });
  const name = `QLToaNha_TV4_WebTest_${crypto.randomBytes(4).toString("hex")}`;
  const config = sqlConfig();
  const master = new sql.ConnectionPool({ ...config, database: "master", pool: { max: 1, min: 1 } });
  let sandbox;
  let store;
  let apiStore;
  let httpServer;
  let created = false;
  try {
    await master.connect();
    await master.request().batch(`CREATE DATABASE [${name}]`);
    created = true;
    sandbox = new sql.ConnectionPool({ ...config, database: name, pool: { max: 1, min: 1 } });
    await sandbox.connect();
    await runSql(sandbox, "database/schema/01_CreateSchema_TV3_NguyenThiLanAnh.sql", name, 3);
    await runSql(sandbox, "database/schema/02_InsertSeedData_TV3_NguyenThiLanAnh.sql", name, 1);
    // Migration thống nhất chạy an toàn trên schema 18 bảng
    for (let pass = 0; pass < 2; pass++)
      await runSql(sandbox, "database/schema/06_ThongNhatQuyTac_TV3_NguyenThiLanAnh.sql", name);
    assert.equal((await sandbox.request().query(`SELECT COUNT(*) AS total FROM sys.check_constraints
      WHERE name IN ('CK_HopDongThue_Ngay','CK_SuDungDichVu_Ngay','CK_NhanVienCongTy_NgayNghi','CK_DichVu_DonGia')
        AND is_disabled = 0 AND is_not_trusted = 0`)).recordset[0].total, 4);
    await runSql(sandbox, "database/triggers/05_Phan5_Triggers_TV5_KhucTuanAnh.sql", name);
    store = new SqlStore({ ...config, database: name });
    assert.equal((await store.health()).transactionsReady, false);
    assert.equal((await store.health()).paymentReady, false);
    await runSql(sandbox, "database/transactions/02_KiemTraTuongThich_TV4_VuTrungHieu.sql", name);
    await runSql(sandbox, "database/transactions/00_TaoKieuDuLieu_TV4_VuTrungHieu.sql", name);
    await runSql(sandbox, "database/transactions/03_Transactions_TV4_VuTrungHieu.sql", name);
    assert.equal((await sandbox.request().query("SELECT COUNT(*) AS total FROM sys.triggers WHERE name LIKE 'TR_%'")).recordset[0].total >= 6, true);
    assert.equal((await store.health()).transactionsReady, true);
    assert.equal((await store.health()).paymentReady, true);

    await sandbox.request().batch(`
      INSERT dbo.ToaNha(MaToaNha,TenToaNha,DiaChi,SoTang) VALUES('WEB_TN',N'Web test',N'Test',2);
      INSERT dbo.CongTy(MaCongTy,TenCongTy,MaSoThue,DiaChi,LinhVuc) VALUES('WEB_CT',N'Web test','0109999977',N'Test',N'Test');
      INSERT dbo.VanPhong(MaVanPhong,MaToaNha,MaViTri,Tang,DienTich)
        VALUES('WEB_P1','WEB_TN','VT_TRONG',1,80),('WEB_P2','WEB_TN','VT_TRONG',1,30);
      INSERT dbo.DichVu(MaDichVu,MaToaNha,MaLoaiDV,TenDichVu,DonGiaCoBan)
        VALUES('WEB_AU','WEB_TN','AN_UONG',N'An test',25000);
      INSERT dbo.NhanVienCongTy(MaNVCT,MaCongTy,HoTen,GioiTinh,NgaySinh,ChucVu,NgayVaoLam)
        VALUES('WEB_NV','WEB_CT',N'Nhan vien','M','20000101',N'Test','20260701');
      INSERT dbo.NhanVienToaNha(MaNVTN,MaToaNha,MaQuanLy,LoaiNV,HoTen,GioiTinh,NgaySinh,NgayVaoLam)
        VALUES('WEB_QL','WEB_TN',NULL,'QUAN_LY',N'Quan ly','M','19900101','20260701');
      INSERT dbo.NhanVienToaNha(MaNVTN,MaToaNha,MaQuanLy,LoaiNV,HoTen,GioiTinh,NgaySinh,NgayVaoLam)
        VALUES('WEB_DV','WEB_TN','WEB_QL','DICH_VU',N'Dich vu','F','20000101','20260701');
      INSERT dbo.PhanCongNVTN(MaNVTN,Thang,Nam,MaDichVu,MaBac)
        VALUES('WEB_QL',8,2026,NULL,'BAC_QL'),('WEB_DV',8,2026,'WEB_AU','BAC_AN');
    `);

    const lease = { companyId: "WEB_CT", buildingId: "WEB_TN", startDate: "2026-08-01", endDate: "2026-09-30", officeIds: ["WEB_P1", "WEB_P2"] };
    const contracts = await executeTransaction(store, "contract", lease);
    assert.equal(contracts.rows.length, 2);
    assert.equal((await sandbox.request().query("SELECT COUNT(*) AS total FROM dbo.HopDongThue WHERE MaCongTy='WEB_CT'")).recordset[0].total, 2);
    await assert.rejects(executeTransaction(store, "contract", lease), (error) => tv4Error(error)?.code === "51106");

    process.env.DB_DATABASE = name;
    process.env.DATA_MODE = "sqlserver";
    const { app, sqlStore } = require("../server/index");
    apiStore = sqlStore;
    httpServer = app.listen(0, "127.0.0.1");
    await new Promise((resolve) => httpServer.once("listening", resolve));
    const endpoint = `http://127.0.0.1:${httpServer.address().port}/api/transactions`;
    const post = (kind, body) => fetch(`${endpoint}/${kind}`, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body)
    });
    const duplicate = await post("contract", lease);
    assert.equal(duplicate.status, 409);
    assert.equal((await duplicate.json()).code, "51106");
    const invalid = await post("contract", { ...lease, officeIds: [] });
    assert.equal(invalid.status, 422);
    assert.equal((await invalid.json()).code, "VALIDATION_ERROR");
    const invalidPayment = await post("payment", {});
    assert.equal(invalidPayment.status, 422);
    assert.equal((await invalidPayment.json()).code, "VALIDATION_ERROR");

    await sandbox.request().query("INSERT dbo.SuDungDichVu(MaCongTy,MaDichVu,NgayBatDau,NgayKetThuc) VALUES('WEB_CT','WEB_AU','20260801','20260930')");
    const uses = { items: [
      { employeeId: "WEB_NV", serviceId: "WEB_AU", useDate: "2026-08-01", quantity: 1 },
      { employeeId: "WEB_NV", serviceId: "WEB_AU", useDate: "2026-08-02", quantity: 4 }
    ] };
    await assert.rejects(executeTransaction(store, "daily-service", { items: [...uses.items,
      { employeeId: "MISSING", serviceId: "WEB_AU", useDate: "2026-08-03", quantity: 1 }] }),
    (error) => tv4Error(error)?.code === "51202");
    assert.equal((await sandbox.request().query("SELECT COUNT(*) AS total FROM dbo.ChiTietSuDungNV WHERE MaDichVu='WEB_AU'")).recordset[0].total, 0);
    assert.equal((await executeTransaction(store, "daily-service", uses)).rows[0].SoDongDaGhi, 2);
    await assert.rejects(executeTransaction(store, "daily-service", uses), (error) => tv4Error(error)?.code === "51204");
    const apiUse = await post("daily-service", { items: [
      { employeeId: "WEB_NV", serviceId: "WEB_AU", useDate: "2026-08-03", quantity: 2 }
    ] });
    assert.equal(apiUse.status, 200);
    assert.equal((await apiUse.json()).rows[0].SoDongDaGhi, 1);

    const period = { buildingId: "WEB_TN", month: 8, year: 2026 };
    await assert.rejects(executeTransaction(store, "payroll", period), (error) => tv4Error(error)?.code === "51502");
    const invoices = await executeTransaction(store, "invoice", period);
    assert.equal(invoices.rows.length, 1);
    assert.ok(Number(invoices.rows[0].TongTien) > 0);
    await assert.rejects(executeTransaction(store, "invoice", period), (error) => tv4Error(error)?.code === "51304");
    const payroll = await executeTransaction(store, "payroll", period);
    assert.equal(payroll.rows.length, 2);
    await assert.rejects(executeTransaction(store, "payroll", period), (error) => tv4Error(error)?.code === "51503");

    // TV6 sửa: thanh toán sai tiền không đổi trạng thái, trả đủ một lần mới vào báo cáo thu.
    const paymentDate = (await sandbox.request().query("SELECT CONVERT(char(10), GETDATE(), 23) AS today")).recordset[0].today;
    const paymentBody = { invoiceId: invoices.rows[0].MaHoaDon,
      amount: Number(invoices.rows[0].TongTien), paymentDate, collector: "Web test" };
    assert.ok((await store.lookups()).unpaidInvoices.some((row) => row.id === paymentBody.invoiceId));
    const missing = await post("payment", { ...paymentBody, invoiceId: 2147483647 });
    assert.equal(missing.status, 409);
    assert.equal((await missing.json()).code, "51402");
    const unknown = await post("unknown", {});
    assert.equal(unknown.status, 404);
    const before = await store.report("building-cashflow", { buildingId: "WEB_TN" });
    assert.equal(before.summary.totalIncome, 0);
    const wrong = await post("payment", { ...paymentBody, amount: paymentBody.amount - 0.01 });
    assert.equal(wrong.status, 409);
    assert.equal((await wrong.json()).code, "51406");
    assert.equal((await sandbox.request().query("SELECT TrangThai FROM dbo.HoaDonThang WHERE MaToaNha='WEB_TN'")).recordset[0].TrangThai, "CHUA_THANH_TOAN");
    const payment = await post("payment", paymentBody);
    assert.equal(payment.status, 200);
    assert.equal(Number((await payment.json()).rows[0].SoTienDaThu), paymentBody.amount);
    const again = await post("payment", paymentBody);
    assert.equal(again.status, 409);
    assert.equal((await again.json()).code, "51403");
    const after = await store.report("building-cashflow", { buildingId: "WEB_TN" });
    assert.equal(after.summary.totalIncome, paymentBody.amount);
    assert.equal((await store.lookups()).unpaidInvoices.some((row) => row.id === paymentBody.invoiceId), false);
    // TV6 sửa: hai yêu cầu cùng thanh toán một hóa đơn không được cùng báo thành công.
    const september = await executeTransaction(store, "invoice", { buildingId: "WEB_TN", month: 9, year: 2026 });
    const concurrentBody = { ...paymentBody, invoiceId: september.rows[0].MaHoaDon,
      amount: Number(september.rows[0].TongTien) };
    const simultaneous = await Promise.all([post("payment", concurrentBody), post("payment", concurrentBody)]);
    assert.deepEqual(simultaneous.map((response) => response.status).sort(), [200, 409]);
    const rejected = simultaneous.find((response) => response.status === 409);
    assert.equal((await rejected.json()).code, "51403");
    const finalReport = await store.report("building-cashflow", { buildingId: "WEB_TN" });
    assert.equal(finalReport.summary.totalIncome, paymentBody.amount + concurrentBody.amount);
    t.diagnostic("TV4 năm giao dịch chạy trên 18 bảng; sai tiền bị từ chối, thanh toán đồng thời chỉ một lần thành công và báo cáo thu khớp.");
  } finally {
    if (httpServer) await new Promise((resolve, reject) => httpServer.close((error) => error ? reject(error) : resolve()));
    if (apiStore?.poolPromise) await (await apiStore.poolPromise).close();
    if (store?.poolPromise) await (await store.poolPromise).close();
    if (sandbox) await sandbox.close();
    if (created) await master.request().batch(`ALTER DATABASE [${name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [${name}]`);
    await master.close();
  }
});
