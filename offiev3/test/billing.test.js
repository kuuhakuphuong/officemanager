const test = require("node:test");
const assert = require("node:assert/strict");
const { money, monthDays, buildInvoices, buildPayroll } = require("../server/mongo/billing");
const { validateTransaction } = require("../server/validation");

const thongSo = { NGUONG_NGUOI: 10, BUOC_NGUOI: 5, NGUONG_DIEN_TICH: 100, BUOC_DIEN_TICH: 10, TY_LE_TANG_GIA: 0.05 };
const loaiDichVu = {
  AN_UONG: { kieuTinhPhi: "LUOT", coTinhTheoNguoi: 0, coTinhTheoDienTich: 0 },
  VE_SINH: { kieuTinhPhi: "THANG", coTinhTheoNguoi: 1, coTinhTheoDienTich: 1 }
};

test("money rounds to two decimals like DECIMAL(18,2)", () => {
  assert.equal(money(1.005), 1.01);
  assert.equal(money(0.1 + 0.2), 0.3);
});

test("monthDays returns the real number of days of the month", () => {
  assert.equal(monthDays(2026, 2).dim, 28);
  assert.equal(monthDays(2026, 8).dim, 31);
});

function baseCtx(overrides = {}) {
  return {
    thongSo, loaiDichVu,
    viTri: { VT_TRONG: 200000 },
    toaNha: { vanPhong: [{ maVanPhong: "VP01", maViTri: "VT_TRONG", dienTich: 80 }],
      dichVu: [{ maDichVu: "VS01", maLoaiDV: "VE_SINH", donGiaCoBan: 1000000 },
        { maDichVu: "AN01", maLoaiDV: "AN_UONG", donGiaCoBan: 35000 }] },
    congTy: [{ maCongTy: "CT01", dichVuDangKy: [{ maDichVu: "VS01", ngayBatDau: "2026-01-01", ngayKetThuc: null },
      { maDichVu: "AN01", ngayBatDau: "2026-01-01", ngayKetThuc: null }] }],
    hopDong: [{ maCongTy: "CT01", maVanPhong: "VP01", ngayBatDau: "2026-01-01", ngayKetThuc: null }],
    nhanVienCongTy: Array.from({ length: 12 }, (_, i) => ({ maNVCT: `NV${i}`, maCongTy: "CT01",
      ngayVaoLam: "2025-01-01", ngayNghiViec: null })),
    nhatKy: [{ maNVCT: "NV0", maDichVu: "AN01", soLuot: 3, donGiaApDung: 35000 }],
    ...overrides
  };
}

test("invoice: rent is prorated by covered days; monthly service uses tier surcharge", () => {
  const [hd] = buildInvoices(baseCtx(), 2026, 2);
  assert.equal(hd.maCongTy, "CT01");
  const rent = hd.chiTiet.find((l) => l.loaiKhoan === "THUE_VAN_PHONG");
  assert.equal(rent.tyLeNgay, 1);
  assert.equal(rent.soTien, money(80 * 200000));
  // 12 người (ngưỡng 10, bước 5) -> bậc 1; diện tích 80 (<=100) -> bậc 0; giá = 1.000.000 * 1.05
  const monthly = hd.chiTiet.find((l) => l.loaiKhoan === "DICH_VU_THANG");
  assert.equal(monthly.donGiaApDung, 1050000);
  const usage = hd.chiTiet.find((l) => l.loaiKhoan === "DICH_VU_LUOT");
  assert.equal(usage.soLuong, 3);
  assert.equal(usage.soTien, money(3 * 35000));
  assert.equal(hd.tongTien, money(hd.chiTiet.reduce((s, l) => s + l.soTien, 0)));
});

test("invoice: a monthly service without any lease in the month is rejected (51307)", () => {
  const ctx = baseCtx({ hopDong: [] });
  assert.throws(() => buildInvoices(ctx, 2026, 2), (e) => e.errno === 51307);
});

test("invoice: an empty period is rejected (51308)", () => {
  const ctx = baseCtx({ congTy: [], hopDong: [], nhatKy: [] });
  assert.throws(() => buildInvoices(ctx, 2026, 2), (e) => e.errno === 51308);
});

test("payroll: bonus = revenue of the assigned service x bonus ratio", () => {
  const invoices = [{ chiTiet: [{ loaiKhoan: "DICH_VU_LUOT", maDichVu: "AN01", soTien: 1000000 }] }];
  const rows = buildPayroll([{ maNVTN: "NVAN01", maBac: "BAC_AN", maDichVu: "AN01" }],
    { BAC_AN: { luongCoBan: 8000000, heSoDoanhThu: 0.05 } }, invoices);
  assert.deepEqual(rows[0], { maNVTN: "NVAN01", maBac: "BAC_AN", maDichVu: "AN01", luongCoBan: 8000000, tienThuong: 50000 });
});

test("validation keeps the API contract of the transaction endpoints", () => {
  assert.throws(() => validateTransaction("payment", { invoiceId: 1, amount: 10.123, paymentDate: "2026-09-01" }));
  assert.throws(() => validateTransaction("contract", { companyId: "CT01", buildingId: "TN01", startDate: "2026-09-02",
    endDate: "2026-09-01", officeIds: ["VP01"] }));
  assert.deepEqual(validateTransaction("payroll", { buildingId: "TN01", month: 8, year: 2026 }),
    { buildingId: "TN01", month: 8, year: 2026 });
  assert.equal(validateTransaction("unknown", {}), null);
});
