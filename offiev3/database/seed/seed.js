// Bộ dữ liệu mẫu cho MongoDB (thiết kế riêng, không sao chép từ MySQL).
// - Sinh dữ liệu gốc bằng bộ sinh số giả ngẫu nhiên có seed cố định (cùng cấu hình ra cùng dữ liệu).
// - Hóa đơn và lương được tính bằng server/mongo/billing.js: cùng công thức với giao dịch thật.
// Chạy: MONGO_URI=... node database/seed/seed.js [--check]

const { MongoClient } = require("mongodb");
const { buildInvoices, buildPayroll, ymd, monthDays, money } = require("../../server/mongo/billing");
const { COLLECTIONS } = require("../../server/mongo/collections");

const SEED = 20260801;
const MONTHS = [{ thang: 8, nam: 2026 }, { thang: 9, nam: 2026 }];

// Bộ sinh số giả ngẫu nhiên (mulberry32): cùng SEED -> cùng dữ liệu.
function random(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const pick = (rand, list) => list[Math.floor(rand() * list.length)];
const between = (rand, min, max) => min + Math.floor(rand() * (max - min + 1));

const SURNAMES = ["Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Vũ", "Đặng", "Bùi", "Đỗ", "Ngô"];
const MALE_MIDDLE = ["Văn", "Đức", "Quốc", "Minh", "Hữu", "Thành"];
const FEMALE_MIDDLE = ["Thị", "Ngọc", "Thu", "Kim", "Phương", "Khánh"];
const MALE_GIVEN = ["Anh", "Hùng", "Dũng", "Khoa", "Long", "Tuấn", "Nam", "Sơn", "Đạt", "Hiếu"];
const FEMALE_GIVEN = ["Lan", "Hoa", "Mai", "Linh", "Hương", "Trang", "Nga", "Thảo", "Yến", "Ngân"];
const COLLECTORS = ["Nguyễn Thị Thu Hà", "Trần Văn Bình", "Lê Thị Kim Oanh"];

const BUILDINGS = [
  { maToaNha: "TN01", tenToaNha: "Tòa nhà Thăng Long Center", diaChi: "Số 10 Duy Tân, Cầu Giấy, Hà Nội", soTang: 9, site: 1 },
  { maToaNha: "TN02", tenToaNha: "Tòa nhà Sông Hàn Business", diaChi: "Số 120 Bạch Đằng, Hải Châu, Đà Nẵng", soTang: 10, site: 2 },
  { maToaNha: "TN03", tenToaNha: "Tòa nhà Sài Gòn Tower", diaChi: "Số 25 Lê Duẩn, Quận 1, TP. Hồ Chí Minh", soTang: 11, site: 3 }
];

const COMPANIES = [
  ["CT01", "Công ty TNHH Giải pháp Phần mềm Thăng Long", "0101234501", "Số 5 Phạm Hùng, Nam Từ Liêm, Hà Nội", "0243123401", "contact@thanglongsoft.vn", "Công nghệ thông tin", "TN01"],
  ["CT02", "Công ty Cổ phần Thương mại Hoàng Hà", "0101234502", "Số 18 Nguyễn Chí Thanh, Đống Đa, Hà Nội", "0243123402", "info@hoanghatrade.vn", "Thương mại", "TN01"],
  ["CT03", "Công ty TNHH Tư vấn Tài chính Bình Minh", "0101234503", "Số 9 Láng Hạ, Ba Đình, Hà Nội", "0243123403", "hello@binhminhfin.vn", "Tài chính", "TN02"],
  ["CT04", "Công ty Cổ phần Logistics Sông Hồng", "0101234504", "Số 33 Trần Phú, Hà Đông, Hà Nội", "0243123404", "sales@songhonglogistics.vn", "Logistics", "TN02"],
  ["CT05", "Công ty TNHH Dược phẩm An Khang", "0101234505", "Số 71 Hoàng Quốc Việt, Cầu Giấy, Hà Nội", "0243123405", "cskh@ankhangpharma.vn", "Dược phẩm", "TN03"],
  ["CT06", "Công ty Cổ phần Đầu tư Sao Mai", "0101234506", "Số 2 Cầu Giấy, Ba Đình, Hà Nội", "0243123406", "contact@saomai-invest.vn", "Bất động sản", "TN03"]
];

// Mỗi công ty thuê hai văn phòng trong tòa của mình (4 văn phòng mỗi tòa).
const OFFICE_PLAN = { TN01: ["VP01", "VP02", "VP03", "VP04"], TN02: ["VP05", "VP06", "VP07", "VP08"], TN03: ["VP09", "VP10", "VP11", "VP12"] };

function generate() {
  const rand = random(SEED);
  const thongSo = [
    { _id: "NGUONG_NGUOI", giaTri: 10, moTa: "Ngưỡng số người để tính bậc giá dịch vụ tháng" },
    { _id: "BUOC_NGUOI", giaTri: 5, moTa: "Bước tăng số người cho mỗi bậc giá" },
    { _id: "NGUONG_DIEN_TICH", giaTri: 100, moTa: "Ngưỡng diện tích (m2) để tính bậc giá" },
    { _id: "BUOC_DIEN_TICH", giaTri: 10, moTa: "Bước tăng diện tích (m2) cho mỗi bậc" },
    { _id: "TY_LE_TANG_GIA", giaTri: 0.05, moTa: "Tỷ lệ tăng giá cho mỗi bậc" }
  ];
  const viTri = [
    { _id: "VT_TRONG", tenViTri: "Khu vực trong nhà", donGiaThueM2: 200000 },
    { _id: "VT_MAT_TIEN", tenViTri: "Mặt tiền đường", donGiaThueM2: 250000 }
  ];
  const loaiDichVu = [
    { _id: "AN_UONG", tenLoai: "Ăn uống", kieuTinhPhi: "LUOT", coTinhTheoNguoi: 0, coTinhTheoDienTich: 0 },
    { _id: "GUI_XE", tenLoai: "Gửi xe", kieuTinhPhi: "LUOT", coTinhTheoNguoi: 0, coTinhTheoDienTich: 0 },
    { _id: "VE_SINH", tenLoai: "Vệ sinh văn phòng", kieuTinhPhi: "THANG", coTinhTheoNguoi: 1, coTinhTheoDienTich: 1 }
  ];
  const bacCongViec = [
    { _id: "BAC_QL", tenBac: "Quản lý tòa nhà", luongCoBan: 18000000, heSoDoanhThu: 0 },
    { _id: "BAC_AN", tenBac: "Nhân viên nhà ăn", luongCoBan: 8000000, heSoDoanhThu: 0.05 },
    { _id: "BAC_XE", tenBac: "Nhân viên bãi xe", luongCoBan: 7500000, heSoDoanhThu: 0.04 }
  ];

  // Tòa nhà: văn phòng, dịch vụ và nhân viên được nhúng trong tài liệu tòa.
  const buildings = BUILDINGS.map((b) => {
    const n = b.maToaNha.slice(2);
    const vanPhong = OFFICE_PLAN[b.maToaNha].map((maVanPhong, i) => ({
      maVanPhong, maViTri: i % 2 === 0 ? "VT_TRONG" : "VT_MAT_TIEN", tang: 2 + i, dienTich: i % 2 === 0 ? 80 : 120 }));
    const dichVu = [
      { maDichVu: `AN${n}`, maLoaiDV: "AN_UONG", tenDichVu: "Bữa trưa", donGiaCoBan: 35000 },
      { maDichVu: `XE${n}`, maLoaiDV: "GUI_XE", tenDichVu: "Gửi xe máy", donGiaCoBan: 5000 },
      { maDichVu: `VS${n}`, maLoaiDV: "VE_SINH", tenDichVu: "Vệ sinh", donGiaCoBan: 1500000 }
    ];
    const nhanVien = [
      { maNVTN: `QL${n}`, hoTen: pick(rand, SURNAMES) + " " + pick(rand, MALE_MIDDLE) + " " + pick(rand, MALE_GIVEN), gioiTinh: "M",
        ngaySinh: "1983-05-14", dienThoai: `09120000${n}`, email: `quanly.${b.site}@tonha.example.vn`, ngayVaoLam: "2026-01-01",
        loai: "QUAN_LY", maQuanLy: null, phanCong: MONTHS.map((m) => ({ thang: m.thang, nam: m.nam, maDichVu: null, maBac: "BAC_QL" })) },
      { maNVTN: `NVAN${n}`, hoTen: pick(rand, SURNAMES) + " " + pick(rand, FEMALE_MIDDLE) + " " + pick(rand, FEMALE_GIVEN), gioiTinh: "F",
        ngaySinh: "1992-03-08", dienThoai: null, email: `nhaan.${b.site}@tonha.example.vn`, ngayVaoLam: "2026-01-01",
        loai: "DICH_VU", maQuanLy: `QL${n}`, phanCong: MONTHS.map((m) => ({ thang: m.thang, nam: m.nam, maDichVu: `AN${n}`, maBac: "BAC_AN" })) },
      { maNVTN: `NVXE${n}`, hoTen: pick(rand, SURNAMES) + " " + pick(rand, MALE_MIDDLE) + " " + pick(rand, MALE_GIVEN), gioiTinh: "M",
        ngaySinh: "1992-11-21", dienThoai: null, email: `baixe.${b.site}@tonha.example.vn`, ngayVaoLam: "2026-01-01",
        loai: "DICH_VU", maQuanLy: `QL${n}`, phanCong: MONTHS.map((m) => ({ thang: m.thang, nam: m.nam, maDichVu: `XE${n}`, maBac: "BAC_XE" })) }
    ];
    return { _id: b.maToaNha, maToaNha: b.maToaNha, tenToaNha: b.tenToaNha, diaChi: b.diaChi, soTang: b.soTang,
      site: b.site, vanPhong, dichVu, nhanVien, version: 0 };
  });

  // Công ty: dịch vụ đăng ký nhúng trong tài liệu; nhân viên là collection riêng.
  const companies = COMPANIES.map(([maCongTy, tenCongTy, maSoThue, diaChi, dienThoai, email, linhVuc, maToaNha]) => {
    const building = buildings.find((b) => b.maToaNha === maToaNha);
    return { _id: maCongTy, maCongTy, tenCongTy, maSoThue, diaChi, dienThoai, email, linhVuc, maToaNha,
      dichVuDangKy: building.dichVu.map((d) => ({ maDichVu: d.maDichVu, maToaNha, ngayBatDau: "2026-07-01", ngayKetThuc: null })) };
  });

  // Hợp đồng: hai văn phòng mỗi công ty, 12 tháng từ 01/07/2026.
  const hopDong = COMPANIES.flatMap(([maCongTy, , , , , , , maToaNha], idx) => {
    const offices = OFFICE_PLAN[maToaNha].slice((idx % 2) * 2, (idx % 2) * 2 + 2);
    return offices.map((maVanPhong) => ({ _id: `HD${maCongTy}${maVanPhong}`, maHopDong: `HD${maCongTy}${maVanPhong}`,
      maCongTy, maToaNha, maVanPhong, ngayBatDau: "2026-07-01", ngayKetThuc: "2027-06-30" }));
  });

  // Nhân viên công ty: 10 người mỗi công ty; một người nghỉ việc giữa tháng 9.
  const nhanVienCongTy = [];
  let counter = 0;
  for (const [maCongTy] of COMPANIES) {
    for (let i = 0; i < 10; i++) {
      counter++;
      const female = rand() < 0.5;
      const maNVCT = `NVCT${String(counter).padStart(3, "0")}`;
      nhanVienCongTy.push({ _id: maNVCT, maNVCT, maCongTy, hoTen: pick(rand, SURNAMES) + " " +
        (female ? pick(rand, FEMALE_MIDDLE) + " " + pick(rand, FEMALE_GIVEN) : pick(rand, MALE_MIDDLE) + " " + pick(rand, MALE_GIVEN)),
        gioiTinh: female ? "F" : "M", ngaySinh: ymd(between(rand, 1985, 2000), between(rand, 1, 12), between(rand, 1, 28)),
        dienThoai: `09${between(rand, 10000000, 99999999)}`, email: `${maNVCT.toLowerCase()}@${maCongTy.toLowerCase()}.example.vn`,
        chucVu: pick(rand, ["Chuyên viên", "Nhân viên kinh doanh", "Kế toán viên", "Trưởng nhóm"]),
        ngayVaoLam: ymd(2026, between(rand, 1, 6), between(rand, 1, 28)),
        ngayNghiViec: maNVCT === "NVCT010" ? "2026-09-15" : null });
    }
  }

  // Nhật ký dịch vụ: ngày làm việc (T2-T6), mỗi nhân viên dùng dịch vụ ăn/gửi xe theo xác suất.
  const nhatKy = [];
  const priceOf = (maDichVu) => buildings.flatMap((b) => b.dichVu).find((d) => d.maDichVu === maDichVu).donGiaCoBan;
  for (const nv of nhanVienCongTy) {
    const maToaNha = companies.find((c) => c.maCongTy === nv.maCongTy).maToaNha;
    const n = maToaNha.slice(2);
    const lastDay = nv.ngayNghiViec || "2026-09-30";
    for (const month of MONTHS) {
      const { dim, days } = monthDays(month.nam, month.thang);
      for (const day of days) {
        if (day > lastDay || day < nv.ngayVaoLam) continue;
        const dow = new Date(`${day}T00:00:00Z`).getUTCDay();
        if (dow === 0 || dow === 6) continue;
        if (rand() < 0.8) nhatKy.push({ maToaNha, maCongTy: nv.maCongTy, maNVCT: nv.maNVCT, maDichVu: `AN${n}`, ngaySuDung: day, soLuot: rand() < 0.7 ? 1 : 2, donGiaApDung: priceOf(`AN${n}`) });
        if (rand() < 0.3) nhatKy.push({ maToaNha, maCongTy: nv.maCongTy, maNVCT: nv.maNVCT, maDichVu: `XE${n}`, ngaySuDung: day, soLuot: 1, donGiaApDung: priceOf(`XE${n}`) });
      }
    }
  }

  // Chi phí vận hành: biến thiên theo tháng và tòa.
  const chiPhiVanHanh = [];
  let costId = 0;
  for (const b of buildings) for (const month of MONTHS) {
    for (const [loai, min, max] of [["Điện nước", 11000000, 13500000], ["Bảo trì thang máy", 4000000, 6500000], ["Vật tư văn phòng", 2000000, 4000000]]) {
      costId++;
      chiPhiVanHanh.push({ _id: costId, maToaNha: b.maToaNha, thang: month.thang, nam: month.nam, loaiChiPhi: loai,
        soTien: between(rand, min, max), moTa: `${loai} tháng ${month.thang}/${month.nam}` });
    }
  }

  // Hóa đơn: cùng công thức giao dịch thật (billing.js), đánh số tuần tự.
  const hoaDon = [];
  let invoiceId = 0;
  for (const b of buildings) {
    const ctx = {
      thongSo: Object.fromEntries(thongSo.map((t) => [t._id, t.giaTri])),
      viTri: Object.fromEntries(viTri.map((v) => [v._id, v.donGiaThueM2])),
      loaiDichVu: Object.fromEntries(loaiDichVu.map((l) => [l._id, l])),
      toaNha: b,
      congTy: companies.filter((c) => c.maToaNha === b.maToaNha),
      hopDong: hopDong.filter((h) => h.maToaNha === b.maToaNha),
      nhanVienCongTy,
      nhatKy: []
    };
    for (const month of MONTHS) {
      const { dim } = monthDays(month.nam, month.thang);
      const logs = nhatKy.filter((l) => l.maToaNha === b.maToaNha && l.ngaySuDung.slice(0, 7) === ymd(month.nam, month.thang, 1).slice(0, 7));
      const result = buildInvoices({ ...ctx, nhatKy: logs }, month.nam, month.thang);
      for (const hd of result) {
        invoiceId++;
        const paid = month.thang === 8;
        hoaDon.push({ _id: invoiceId, maHoaDon: invoiceId, maCongTy: hd.maCongTy, maToaNha: b.maToaNha, thang: month.thang,
          nam: month.nam, ngayLap: ymd(month.nam, month.thang, dim), trangThai: paid ? "DA_THANH_TOAN" : "CHUA_THANH_TOAN",
          ngayThanhToan: paid ? ymd(month.nam, month.thang, dim + 0) : null, nguoiThu: paid ? pick(rand, COLLECTORS) : null,
          tongTien: hd.tongTien, chiTiet: hd.chiTiet });
      }
    }
  }
  // Ngày thanh toán tháng 8: 5 ngày sau ngày lập (không vượt ngày hiện tại).
  for (const hd of hoaDon) if (hd.ngayThanhToan) hd.ngayThanhToan = ymd(hd.nam, hd.thang + 1, 5);

  // Bảng lương: lập từ phân công và hóa đơn của cùng tháng.
  const bangLuong = [];
  for (const b of buildings) {
    for (const month of MONTHS) {
      const invoices = hoaDon.filter((h) => h.maToaNha === b.maToaNha && h.thang === month.thang && h.nam === month.nam);
      const phanCong = b.nhanVien.map((nv) => {
        const pc = nv.phanCong.find((p) => p.thang === month.thang && p.nam === month.nam);
        return { maNVTN: nv.maNVTN, maBac: pc.maBac, maDichVu: pc.maDichVu, luong: 0 };
      });
      for (const r of buildPayroll(phanCong, Object.fromEntries(bacCongViec.map((x) => [x._id, x])), invoices)) {
        bangLuong.push({ maToaNha: b.maToaNha, maNVTN: r.maNVTN, nam: month.nam, thang: month.thang,
          luongCoBan: r.luongCoBan, tienThuong: r.tienThuong, maDichVu: r.maDichVu, maBac: r.maBac });
      }
    }
  }

  // Tài liệu toà nhà: ghi nhận nhân viên theo tòa (đã nhúng ở trên); tài liệu công ty không chứa nhân viên.
  return { thongSo, viTri, loaiDichVu, bacCongViec, buildings, companies, nhanVienCongTy, hopDong, nhatKy,
    chiPhiVanHanh, hoaDon, bangLuong, nextInvoiceId: invoiceId + 1 };
}

// Nạp dữ liệu vào cụm MongoDB (qua mongos). Giữ nguyên cấu hình sharding đã tạo; chỉ xóa dữ liệu cũ.
async function load(uri, databaseName = "QuanLyToaNha") {
  const client = new MongoClient(uri, { serverSelectionTimeoutMS: 10000 });
  await client.connect();
  const db = client.db(databaseName);
  const data = generate();
  const put = (key, docs) => db.collection(COLLECTIONS[key].name).insertMany(docs, { ordered: true });
  for (const key of Object.keys(COLLECTIONS)) await db.collection(COLLECTIONS[key].name).deleteMany({});

  await put("thongSo", data.thongSo);
  await put("viTri", data.viTri);
  await put("loaiDichVu", data.loaiDichVu);
  await put("bacCongViec", data.bacCongViec);
  await put("toaNha", data.buildings);
  await put("congTy", data.companies);
  await put("nhanVienCongTy", data.nhanVienCongTy);
  await put("hopDongThue", data.hopDong);
  await put("nhatKySuDung", data.nhatKy);
  await put("chiPhiVanHanh", data.chiPhiVanHanh);
  await put("hoaDonThang", data.hoaDon);
  await put("bangLuong", data.bangLuong);
  await db.collection(COLLECTIONS.boDem.name).updateOne({ _id: "hoa_don" }, { $set: { seq: data.nextInvoiceId - 1 } }, { upsert: true });

  // Chỉ mục duy nhất phải chứa khóa phân mảnh (maToaNha) khi collection đã shard.
  await db.collection(COLLECTIONS.hoaDonThang.name).createIndex({ maToaNha: 1, maHoaDon: 1 }, { unique: true });
  await db.collection(COLLECTIONS.hoaDonThang.name).createIndex({ maToaNha: 1, maCongTy: 1, nam: 1, thang: 1 }, { unique: true });
  await db.collection(COLLECTIONS.nhatKySuDung.name).createIndex({ maToaNha: 1, maNVCT: 1, maDichVu: 1, ngaySuDung: 1 }, { unique: true });
  await db.collection(COLLECTIONS.bangLuong.name).createIndex({ maToaNha: 1, maNVTN: 1, nam: 1, thang: 1 }, { unique: true });

  // Chỉ mục cho tìm kiếm và lọc vận hành (không unique trên collection đã shard, trừ khi có khóa phân mảnh).
  //  - cong_ty: lọc theo lĩnh vực.
  //  - hop_dong_thue: lọc theo công ty + ngày bắt đầu (hiệu lực), theo văn phòng + ngày kết thúc (kiểm tra chồng lịch).
  //  - nhan_vien_cong_ty: lọc theo công ty, sắp xếp theo họ tên.
  //  - toa_nha (mảng nhúng): tra cứu văn phòng/dịch vụ/nhân viên theo mã (multikey).
  await db.collection(COLLECTIONS.congTy.name).createIndex({ linhVuc: 1 });
  await db.collection(COLLECTIONS.hopDongThue.name).createIndex({ maCongTy: 1, ngayBatDau: 1 });
  await db.collection(COLLECTIONS.hopDongThue.name).createIndex({ maVanPhong: 1, ngayKetThuc: 1 });
  await db.collection(COLLECTIONS.nhanVienCongTy.name).createIndex({ maCongTy: 1, hoTen: 1 });
  await db.collection(COLLECTIONS.toaNha.name).createIndex({ "vanPhong.maVanPhong": 1 });
  await db.collection(COLLECTIONS.toaNha.name).createIndex({ "dichVu.maDichVu": 1 });

  await client.close();
  return {
    buildings: data.buildings.length, companies: data.companies.length, employees: data.nhanVienCongTy.length,
    contracts: data.hopDong.length, usageLogs: data.nhatKy.length, invoices: data.hoaDon.length, payroll: data.bangLuong.length
  };
}

if (require.main === module) {
  const uri = process.env.MONGO_URI;
  if (!uri) throw new Error("Thiếu MONGO_URI");
  load(uri, process.env.MONGO_DATABASE || "QuanLyToaNha")
    .then((counts) => console.log(`[OK] Đã nạp dữ liệu MongoDB: ${JSON.stringify(counts)}`))
    .catch((error) => { console.error(error); process.exit(1); });
}

module.exports = { generate, load };
