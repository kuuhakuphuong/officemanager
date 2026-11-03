// Công thức tính tiền thuần (không truy cập CSDL). Dùng chung cho giao dịch lập hóa đơn/lương
// và cho bộ seed, để số liệu sinh ra và số liệu giao dịch luôn theo cùng một quy tắc.
// Quy tắc gốc: TV3/TV4 (bản MySQL). Tiền làm tròn 2 chữ số thập phân như DECIMAL(18,2).
const { businessError } = require("../errors");

const money = (value) => Math.round((Number(value) + Number.EPSILON) * 100) / 100;
const pad = (value) => String(value).padStart(2, "0");
const ymd = (year, month, day) => `${year}-${pad(month)}-${pad(day)}`;

// Danh sách ngày YYYY-MM-DD của tháng, và số ngày trong tháng.
function monthDays(year, month) {
  const dim = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return { dim, days: Array.from({ length: dim }, (_, i) => ymd(year, month, i + 1)) };
}

const inRange = (day, from, to) => from <= day && (!to || to >= day);

// Bậc giá luỹ tiến: cộng đơn giản bậc theo số người và bậc theo diện tích (không lấy MAX).
function tierOf(value, threshold, step) {
  return value > threshold ? Math.ceil((value - threshold) / step) : 0;
}

// Tạo các dòng hóa đơn của một tòa nhà trong một tháng.
// ctx: { thongSo, viTri, toaNha, congTy, hopDong, nhanVienCongTy, nhatKy, loaiDichVu }
//   toaNha.vanPhong[]  : { maVanPhong, maViTri, dienTich }
//   toaNha.dichVu[]    : { maDichVu, maLoaiDV, donGiaCoBan }
//   congTy[]           : { maCongTy, dichVuDangKy: [{ maDichVu, ngayBatDau, ngayKetThuc }] }
//   hopDong[]          : { maCongTy, maVanPhong, ngayBatDau, ngayKetThuc } (chỉ văn phòng của tòa)
//   nhatKy[]           : { maNVCT, maDichVu, ngaySuDung, soLuot } (chỉ dịch vụ của tòa, trong tháng)
// Trả về: [{ maCongTy, chiTiet: [...], tongTien }] theo thứ tự mã công ty.
function buildInvoices(ctx, year, month) {
  const { thongSo, viTri, toaNha, congTy, hopDong, nhanVienCongTy, nhatKy, loaiDichVu } = ctx;
  const { dim, days } = monthDays(year, month);
  const lines = new Map(); // maCongTy -> [dòng]
  const addLine = (maCongTy, line) => {
    if (!lines.has(maCongTy)) lines.set(maCongTy, []);
    lines.get(maCongTy).push({ ...line, soTien: money(line.soLuong * line.donGiaApDung * line.tyLeNgay) });
  };
  const dichVuById = new Map(toaNha.dichVu.map((d) => [d.maDichVu, d]));
  const dienTichById = new Map(toaNha.vanPhong.map((v) => [v.maVanPhong, v]));

  // 1. Tiền thuê văn phòng: mỗi ngày có hợp đồng hiệu lực được tính (ngày đầu và ngày cuối đều tính).
  const rentDays = new Map(); // maCongTy|maVanPhong -> số ngày
  for (const hd of hopDong) {
    if (!dienTichById.has(hd.maVanPhong)) continue;
    for (const day of days) {
      if (inRange(day, hd.ngayBatDau, hd.ngayKetThuc)) {
        const key = `${hd.maCongTy}|${hd.maVanPhong}`;
        rentDays.set(key, (rentDays.get(key) || 0) + 1);
      }
    }
  }
  for (const [key, count] of rentDays) {
    const [maCongTy, maVanPhong] = key.split("|");
    const vp = dienTichById.get(maVanPhong);
    addLine(maCongTy, { loaiKhoan: "THUE_VAN_PHONG", maVanPhong, maDichVu: null, soLuong: vp.dienTich,
      donGiaApDung: viTri[vp.maViTri], tyLeNgay: count / dim });
  }

  // 2. Dịch vụ tính theo tháng: giá từng ngày theo số người và diện tích thuê của công ty trong tòa.
  const monthlyDays = new Map(); // maCongTy|maDichVu|donGia -> số ngày
  const staffCount = (maCongTy, day) => nhanVienCongTy.filter((nv) => nv.maCongTy === maCongTy &&
    inRange(day, nv.ngayVaoLam, nv.ngayNghiViec)).length;
  for (const ct of congTy) {
    for (const sub of ct.dichVuDangKy || []) {
      const dv = dichVuById.get(sub.maDichVu);
      if (!dv) continue;
      const loai = loaiDichVu[dv.maLoaiDV];
      if (loai.kieuTinhPhi !== "THANG") continue;
      for (const day of days) {
        if (!inRange(day, sub.ngayBatDau, sub.ngayKetThuc)) continue;
        const leased = hopDong.filter((hd) => hd.maCongTy === ct.maCongTy && inRange(day, hd.ngayBatDau, hd.ngayKetThuc));
        if (!leased.length) throw businessError(51307);
        const dienTich = leased.reduce((sum, hd) => sum + (dienTichById.get(hd.maVanPhong)?.dienTich || 0), 0);
        const soNguoi = staffCount(ct.maCongTy, day);
        const bacNguoi = loai.coTinhTheoNguoi ? tierOf(soNguoi, thongSo.NGUONG_NGUOI, thongSo.BUOC_NGUOI) : 0;
        const bacDienTich = loai.coTinhTheoDienTich ? tierOf(dienTich, thongSo.NGUONG_DIEN_TICH, thongSo.BUOC_DIEN_TICH) : 0;
        const donGia = money(dv.donGiaCoBan * (1 + thongSo.TY_LE_TANG_GIA * (bacNguoi + bacDienTich)));
        const key = `${ct.maCongTy}|${dv.maDichVu}|${donGia}`;
        monthlyDays.set(key, (monthlyDays.get(key) || 0) + 1);
      }
    }
  }
  for (const [key, count] of monthlyDays) {
    const [maCongTy, maDichVu, donGia] = key.split("|");
    addLine(maCongTy, { loaiKhoan: "DICH_VU_THANG", maVanPhong: null, maDichVu, soLuong: 1,
      donGiaApDung: Number(donGia), tyLeNgay: count / dim });
  }

  // 3. Dịch vụ theo lượt: cộng số lượt theo công ty của nhân viên, dịch vụ và đơn giá lịch sử.
  const companyOf = new Map(nhanVienCongTy.map((nv) => [nv.maNVCT, nv.maCongTy]));
  const usage = new Map(); // maCongTy|maDichVu|donGia -> số lượt
  for (const log of nhatKy) {
    const maCongTy = companyOf.get(log.maNVCT);
    if (!maCongTy) continue;
    const key = `${maCongTy}|${log.maDichVu}|${log.donGiaApDung}`;
    usage.set(key, (usage.get(key) || 0) + log.soLuot);
  }
  for (const [key, soLuot] of usage) {
    const [maCongTy, maDichVu, donGia] = key.split("|");
    addLine(maCongTy, { loaiKhoan: "DICH_VU_LUOT", maVanPhong: null, maDichVu, soLuong: soLuot,
      donGiaApDung: Number(donGia), tyLeNgay: 1 });
  }

  if (!lines.size) throw businessError(51308);
  return [...lines.keys()].sort().map((maCongTy) => {
    const chiTiet = lines.get(maCongTy);
    return { maCongTy, chiTiet, tongTien: money(chiTiet.reduce((sum, l) => sum + l.soTien, 0)) };
  });
}

// Lương tháng: lương cơ bản theo bậc + thưởng = doanh thu dịch vụ được phân công × hệ số.
// phanCong: [{ maNVTN, maBac, maDichVu, luong }]; hoaDon: [{ chiTiet: [...] }] (cả tòa, trong tháng).
function buildPayroll(phanCong, bacCongViec, hoaDon) {
  const allLines = hoaDon.flatMap((hd) => hd.chiTiet);
  return phanCong.map((pc) => {
    const bac = bacCongViec[pc.maBac];
    const doanhThu = pc.maDichVu
      ? allLines.filter((l) => l.maDichVu === pc.maDichVu && (l.loaiKhoan === "DICH_VU_THANG" || l.loaiKhoan === "DICH_VU_LUOT"))
        .reduce((sum, l) => sum + l.soTien, 0)
      : 0;
    return { maNVTN: pc.maNVTN, maBac: pc.maBac, maDichVu: pc.maDichVu || null,
      luongCoBan: bac.luongCoBan, tienThuong: money(doanhThu * bac.heSoDoanhThu) };
  });
}

module.exports = { money, monthDays, buildInvoices, buildPayroll, ymd, inRange };
