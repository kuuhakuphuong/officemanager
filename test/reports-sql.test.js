const test = require("node:test");
const assert = require("node:assert/strict");

const runSql = process.env.RUN_SQL_REPORT_TESTS === "1";
if (runSql) require("dotenv").config();
const { SqlStore } = require("../server/sql-store");

test("SQL reports reconcile filtered detail with the BCNF source tables", { skip: !runSql }, async () => {
  const store = new SqlStore();
  try {
    const [allCompanies, allServices, allPayroll, allCashflow] = await Promise.all([
      store.report("company-cost", {}), store.report("daily-services", {}),
      store.report("payroll", {}), store.report("building-cashflow", {})
    ]);
    assert.deepEqual([allCompanies.total, allCompanies.summary.invoiceCount,
      allCompanies.summary.totalCost, allCompanies.summary.rentCost,
      allCompanies.summary.monthlyServiceCost, allCompanies.summary.usageServiceCost],
    [60, 12, 725400000, 552000000, 27000000, 146400000]);
    assert.deepEqual([allServices.total, allServices.summary.totalUses,
      allServices.summary.totalCost, allServices.summary.mealUses, allServices.summary.parkingUses],
    [7320, 7320, 146400000, 3660, 3660]);
    assert.deepEqual([allPayroll.total, allPayroll.summary.totalPayroll,
      allPayroll.summary.basePayroll, allPayroll.summary.totalBonus],
    [18, 208137000, 201000000, 7137000]);
    assert.deepEqual([allCashflow.total, allCashflow.summary.totalIncome,
      allCashflow.summary.totalExpense, allCashflow.summary.netCashflow],
    [42, 363900000, 328137000, 35763000]);

    const company = await store.report("company-cost", {
      companyId: "CT01", buildingId: "TN01", from: "2026-08", to: "2026-08"
    });
    assert.ok(company.total > 0, "TV3 seed must contain CT01 invoice detail for August 2026");
    const companySource = (await (await store.request()).query(`SELECT
        COUNT(DISTINCT hd.MaHoaDon) AS invoiceCount,
        SUM(CASE WHEN line.LoaiKhoan = 'THUE_VAN_PHONG' THEN line.SoTien ELSE 0 END) AS rentCost,
        SUM(CASE WHEN line.LoaiKhoan = 'DICH_VU_THANG' THEN line.SoTien ELSE 0 END) AS monthlyServiceCost,
        SUM(CASE WHEN line.LoaiKhoan = 'DICH_VU_LUOT' THEN line.SoTien ELSE 0 END) AS usageServiceCost,
        SUM(line.SoTien) AS totalCost
      FROM dbo.HoaDonThang AS hd
      JOIN dbo.V_ChiTietHoaDon AS line ON line.MaHoaDon = hd.MaHoaDon
      WHERE hd.MaCongTy = 'CT01' AND hd.MaToaNha = 'TN01' AND hd.Nam = 2026 AND hd.Thang = 8`)).recordset[0];
    for (const key of ["invoiceCount", "rentCost", "monthlyServiceCost", "usageServiceCost", "totalCost"])
      assert.equal(company.summary[key], Number(companySource[key] || 0), key);
    assert.equal(company.summary.totalCost, company.rows.reduce((sum, row) => sum + row.amount, 0));
    assert.ok(company.rows.every((row) => row.period === "2026-08" && row.invoice && row.item));
    assert.ok(company.rows.every((row) => row.amount === Math.round(row.quantity * row.unitPrice * row.dayRatio * 100) / 100));

    const services = await store.report("daily-services", {
      companyId: "CT01", buildingId: "TN01", employeeId: "NVCT001",
      serviceType: "AN_UONG", from: "2026-08-01", to: "2026-08-31"
    });
    assert.ok(services.total > 0, "TV3 seed must contain daily service use for NVCT001");
    const serviceSource = (await (await store.request()).query(`SELECT COUNT_BIG(*) AS detailCount,
        SUM(logdv.SoLuot) AS totalUses,
        SUM(CONVERT(decimal(28,2), logdv.SoLuot * logdv.DonGiaApDung)) AS totalCost
      FROM dbo.ChiTietSuDungNV AS logdv
      JOIN dbo.NhanVienCongTy AS nv ON nv.MaNVCT = logdv.MaNVCT
      JOIN dbo.DichVu AS dv ON dv.MaDichVu = logdv.MaDichVu
      WHERE nv.MaCongTy = 'CT01' AND dv.MaToaNha = 'TN01'
        AND logdv.MaNVCT = 'NVCT001' AND dv.MaLoaiDV = 'AN_UONG'
        AND logdv.NgaySuDung BETWEEN '20260801' AND '20260831'`)).recordset[0];
    assert.equal(services.total, Number(serviceSource.detailCount));
    assert.equal(services.summary.totalUses, Number(serviceSource.totalUses));
    assert.equal(services.summary.totalCost, Number(serviceSource.totalCost));
    assert.ok(services.rows.every((row) => row.amount === row.quantity * row.unitPrice));

    const payroll = await store.report("payroll", { buildingId: "TN01", period: "2026-08" });
    assert.ok(payroll.total > 0, "TV3 seed must contain TN01 payroll for August 2026");
    const payrollSource = (await (await store.request()).query(`SELECT COUNT(*) AS employeeCount,
        SUM(payroll.LuongCoBan) AS basePayroll,
        SUM(payroll.TienThuong) AS totalBonus,
        SUM(payroll.LuongCoBan + payroll.TienThuong) AS totalPayroll
      FROM dbo.LuongThang AS payroll
      JOIN dbo.NhanVienToaNha AS nv ON nv.MaNVTN = payroll.MaNVTN
      WHERE nv.MaToaNha = 'TN01' AND payroll.Nam = 2026 AND payroll.Thang = 8`)).recordset[0];
    for (const key of ["employeeCount", "basePayroll", "totalBonus", "totalPayroll"])
      assert.equal(payroll.summary[key], Number(payrollSource[key] || 0), key);
    assert.equal(payroll.summary.totalPayroll, payroll.rows.reduce((sum, row) => sum + row.amount, 0));
    assert.ok(payroll.rows.every((row) => row.amount === row.baseSalary + row.bonus));

    const cashflow = await store.report("building-cashflow", {
      buildingId: "TN01", from: "2026-09-01", to: "2026-09-30"
    });
    assert.ok(cashflow.total > 0, "TV3 seed must contain TN01 receipts and expenses for September 2026");
    const receiptSource = (await (await store.request()).query(`SELECT
        COUNT(DISTINCT hd.MaHoaDon) AS receiptCount, SUM(line.SoTien) AS totalIncome
      FROM dbo.HoaDonThang AS hd
      JOIN dbo.V_ChiTietHoaDon AS line ON line.MaHoaDon = hd.MaHoaDon
      WHERE hd.MaToaNha = 'TN01' AND hd.TrangThai = 'DA_THANH_TOAN'
        AND hd.NgayThanhToan BETWEEN '20260901' AND '20260930'`)).recordset[0];
    const expenseSource = (await (await store.request()).query(`SELECT
        (SELECT SUM(SoTien) FROM dbo.ChiPhiVanHanh
          WHERE MaToaNha = 'TN01' AND Nam = 2026 AND Thang = 9) AS operatingCost,
        (SELECT SUM(payroll.LuongCoBan + payroll.TienThuong)
          FROM dbo.LuongThang AS payroll
          JOIN dbo.NhanVienToaNha AS nv ON nv.MaNVTN = payroll.MaNVTN
          WHERE nv.MaToaNha = 'TN01' AND payroll.Nam = 2026 AND payroll.Thang = 9) AS payrollCost`)).recordset[0];
    const expectedIncome = Number(receiptSource.totalIncome || 0);
    const expectedExpense = Number(expenseSource.operatingCost || 0) + Number(expenseSource.payrollCost || 0);
    assert.equal(cashflow.summary.totalIncome, expectedIncome);
    assert.equal(cashflow.summary.totalExpense, expectedExpense);
    assert.equal(cashflow.summary.netCashflow, expectedIncome - expectedExpense);
    assert.equal(cashflow.summary.entryCount, cashflow.rows.length);
    assert.equal(cashflow.rows.filter((row) => row.type === "Thu").length, Number(receiptSource.receiptCount));
    assert.ok(cashflow.rows.filter((row) => row.type === "Thu")
      .every((row) => row.dateBasis === "Ngày thanh toán" && row.period === "2026-08"));
    assert.ok(cashflow.rows.filter((row) => row.type === "Chi")
      .every((row) => row.dateBasis === "Đầu kỳ kế toán" && row.date === "2026-09-01"));
  } finally {
    if (store.poolPromise) await (await store.poolPromise).close();
  }
});
