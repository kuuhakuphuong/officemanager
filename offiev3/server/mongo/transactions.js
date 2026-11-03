// Năm nghiệp vụ TV4 trên MongoDB. Mỗi nghiệp vụ chạy trong một multi-document transaction.
// Thay vì khóa sp_getapplock/GET_LOCK, mỗi giao dịch ghi `version` vào tài liệu tòa nhà:
// hai giao dịch cùng tòa sẽ xung đột ghi và MongoDB chỉ cho một giao dịch thành công (cùng hiệu lực).
// Mã lỗi giữ nguyên 51xxx để API và giao diện không đổi.
const { businessError, ValidationError } = require("../errors");
const { COLLECTIONS } = require("./collections");
const { money, monthDays, buildInvoices, buildPayroll, ymd, inRange } = require("./billing");

const FAR_FUTURE = "9999-12-31";
const today = () => ymd(new Date().getFullYear(), new Date().getMonth() + 1, new Date().getDate());
const lastDay = (year, month) => ymd(year, month, monthDays(year, month).dim);

// Đọc toàn bộ ngữ cảnh cần để tính hóa đơn/lương của một tòa trong một tháng.
async function loadContext(db, session, maToaNha, year, month) {
  const { dim } = monthDays(year, month);
  const from = ymd(year, month, 1);
  const to = ymd(year, month, dim);
  const toaNha = await db.collection(COLLECTIONS.toaNha.name).findOne({ _id: maToaNha }, { session });
  if (!toaNha) throw businessError(51303);
  const serviceIds = toaNha.dichVu.map((d) => d.maDichVu);
  const officeIds = toaNha.vanPhong.map((v) => v.maVanPhong);
  const [thongSoRows, viTriRows, loaiRows, bacRows, hopDong, congTy, nhatKy] = await Promise.all([
    db.collection(COLLECTIONS.thongSo.name).find({}, { session }).toArray(),
    db.collection(COLLECTIONS.viTri.name).find({}, { session }).toArray(),
    db.collection(COLLECTIONS.loaiDichVu.name).find({}, { session }).toArray(),
    db.collection(COLLECTIONS.bacCongViec.name).find({}, { session }).toArray(),
    db.collection(COLLECTIONS.hopDongThue.name).find({ maToaNha, maVanPhong: { $in: officeIds } }, { session }).toArray(),
    db.collection(COLLECTIONS.congTy.name).find({ "dichVuDangKy.maDichVu": { $in: serviceIds } }, { session }).toArray(),
    db.collection(COLLECTIONS.nhatKySuDung.name).find({ maToaNha, maDichVu: { $in: serviceIds },
      ngaySuDung: { $gte: from, $lte: to } }, { session }).toArray()
  ]);
  const companyIds = [...new Set([...congTy.map((c) => c.maCongTy), ...hopDong.map((h) => h.maCongTy)])];
  const nhanVienCongTy = await db.collection(COLLECTIONS.nhanVienCongTy.name)
    .find({ maCongTy: { $in: companyIds } }, { session }).toArray();
  return {
    toaNha,
    hopDong,
    congTy,
    nhatKy,
    nhanVienCongTy,
    thongSo: Object.fromEntries(thongSoRows.map((t) => [t._id, t.giaTri])),
    viTri: Object.fromEntries(viTriRows.map((v) => [v._id, v.donGiaThueM2])),
    loaiDichVu: Object.fromEntries(loaiRows.map((l) => [l._id, { kieuTinhPhi: l.kieuTinhPhi,
      coTinhTheoNguoi: l.coTinhTheoNguoi, coTinhTheoDienTich: l.coTinhTheoDienTich }])),
    bacCongViec: Object.fromEntries(bacRows.map((b) => [b._id, b]))
  };
}

// Mỗi giao dịch làm tăng version của tòa nhà: hai giao dịch cùng tòa không thể cùng commit.
async function lockBuilding(db, session, maToaNha) {
  await db.collection(COLLECTIONS.toaNha.name).updateOne({ _id: maToaNha }, { $inc: { version: 1 } }, { session });
}

async function nextInvoiceId(db, session) {
  const doc = await db.collection(COLLECTIONS.boDem.name).findOneAndUpdate(
    { _id: "hoa_don" }, { $inc: { seq: 1 } }, { upsert: true, returnDocument: "after", session });
  return doc.seq;
}

// 51101-51106: ký hợp đồng thuê nhiều văn phòng trong một lần.
async function ketHopDongThue(db, session, { companyId, buildingId, startDate, endDate, officeIds }) {
  if (!startDate || (endDate && endDate < startDate) || !officeIds.length) throw businessError(51101);
  const company = await db.collection(COLLECTIONS.congTy.name).findOne({ _id: companyId }, { session });
  const building = await db.collection(COLLECTIONS.toaNha.name).findOne({ _id: buildingId }, { session });
  if (!company || !building) throw businessError(51102);
  const known = new Set(building.vanPhong.map((v) => v.maVanPhong));
  if (officeIds.some((id) => !known.has(id))) throw businessError(51103);
  await lockBuilding(db, session, buildingId);

  const end = endDate || FAR_FUTURE;
  const invoices = await db.collection(COLLECTIONS.hoaDonThang.name).find({ maToaNha: buildingId,
    nam: { $gte: Number(startDate.slice(0, 4)), $lte: Number((end === FAR_FUTURE ? "9999" : end).slice(0, 4)) } },
  { session, projection: { thang: 1, nam: 1 } }).toArray();
  // Kỳ hóa đơn [đầu tháng, cuối tháng] chồng lấn khoảng thuê [startDate, end].
  if (invoices.some((hd) => ymd(hd.nam, hd.thang, 1) <= end && lastDay(hd.nam, hd.thang) >= startDate)) {
    throw businessError(51105);
  }
  const overlap = await db.collection(COLLECTIONS.hopDongThue.name).findOne({ maToaNha: buildingId,
    maVanPhong: { $in: officeIds }, ngayBatDau: { $lte: end },
    $or: [{ ngayKetThuc: null }, { ngayKetThuc: { $gte: startDate } }] }, { session });
  if (overlap) throw businessError(51106);

  const rows = [];
  for (const maVanPhong of officeIds) {
    const maHopDong = `H${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`.toUpperCase();
    await db.collection(COLLECTIONS.hopDongThue.name).insertOne({ _id: maHopDong, maHopDong, maCongTy: companyId,
      maToaNha: buildingId, maVanPhong, ngayBatDau: startDate, ngayKetThuc: endDate || null }, { session });
    rows.push({ MaHopDong: maHopDong, MaVanPhong: maVanPhong });
  }
  return rows.sort((a, b) => a.MaVanPhong.localeCompare(b.MaVanPhong));
}

// 51201-51204: ghi nhật ký dịch vụ theo lô (đúng cả lô hoặc không ghi gì).
async function ghiNhatKyDichVu(db, session, items) {
  const today0 = today();
  if (!items.length || items.some((i) => i.soLuot <= 0 || i.ngaySuDung > today0)) throw businessError(51201);
  const rows = [];
  for (const item of items) {
    const nv = await db.collection(COLLECTIONS.nhanVienCongTy.name).findOne({ _id: item.maNVCT }, { session });
    const building = await db.collection(COLLECTIONS.toaNha.name).findOne({ "dichVu.maDichVu": item.maDichVu }, { session });
    const dv = building?.dichVu.find((d) => d.maDichVu === item.maDichVu);
    if (!nv || !dv || !building) throw businessError(51202);
    const loai = await db.collection(COLLECTIONS.loaiDichVu.name).findOne({ _id: dv.maLoaiDV }, { session });
    const congTy = await db.collection(COLLECTIONS.congTy.name).findOne({ _id: nv.maCongTy }, { session });
    const sub = congTy?.dichVuDangKy.some((s) => s.maDichVu === item.maDichVu && inRange(item.ngaySuDung, s.ngayBatDau, s.ngayKetThuc));
    const lease = await db.collection(COLLECTIONS.hopDongThue.name).findOne({ maToaNha: building._id,
      maCongTy: nv.maCongTy, ngayBatDau: { $lte: item.ngaySuDung },
      $or: [{ ngayKetThuc: null }, { ngayKetThuc: { $gte: item.ngaySuDung } }] }, { session });
    const employed = inRange(item.ngaySuDung, nv.ngayVaoLam, nv.ngayNghiViec);
    if (loai.kieuTinhPhi !== "LUOT" || !employed || !sub || !lease) throw businessError(51202);
    rows.push({ ...item, maToaNha: building._id, maCongTy: nv.maCongTy, donGiaApDung: dv.donGiaCoBan });
  }
  for (const row of rows) {
    const [nam, thang] = [Number(row.ngaySuDung.slice(0, 4)), Number(row.ngaySuDung.slice(5, 7))];
    const closed = await db.collection(COLLECTIONS.hoaDonThang.name).findOne({ maToaNha: row.maToaNha, nam, thang }, { session });
    if (closed) throw businessError(51203);
    const dup = await db.collection(COLLECTIONS.nhatKySuDung.name).findOne({ maToaNha: row.maToaNha,
      maNVCT: row.maNVCT, maDichVu: row.maDichVu, ngaySuDung: row.ngaySuDung }, { session });
    if (dup) throw businessError(51204);
  }
  await lockBuilding(db, session, rows[0].maToaNha);
  await db.collection(COLLECTIONS.nhatKySuDung.name).insertMany(rows.map((r) => ({
    maToaNha: r.maToaNha, maCongTy: r.maCongTy, maNVCT: r.maNVCT, maDichVu: r.maDichVu,
    ngaySuDung: r.ngaySuDung, soLuot: r.soLuot, donGiaApDung: r.donGiaApDung })), { session });
  return [{ SoDongDaGhi: rows.length }];
}

// 51301-51308: lập hóa đơn tháng cho một tòa (mỗi công ty một hóa đơn).
async function lapHoaDonThang(db, session, { buildingId, month, year }) {
  if (!month || month < 1 || month > 12 || !year || year < 1900 || year > 9999) throw businessError(51301);
  if (lastDay(year, month) >= today()) throw businessError(51302);
  await lockBuilding(db, session, buildingId);
  const ctx = await loadContext(db, session, buildingId, year, month);
  const exists = await db.collection(COLLECTIONS.hoaDonThang.name).findOne({ maToaNha: buildingId, nam: year, thang: month }, { session });
  if (exists) throw businessError(51304);
  const result = buildInvoices({ ...ctx, thongSo: ctx.thongSo, viTri: ctx.viTri, loaiDichVu: ctx.loaiDichVu }, year, month);
  const rows = [];
  for (const hd of result) {
    const maHoaDon = await nextInvoiceId(db, session);
    await db.collection(COLLECTIONS.hoaDonThang.name).insertOne({ _id: maHoaDon, maHoaDon, maCongTy: hd.maCongTy,
      maToaNha: buildingId, thang: month, nam: year, ngayLap: today(), trangThai: "CHUA_THANH_TOAN",
      ngayThanhToan: null, nguoiThu: null, tongTien: hd.tongTien, chiTiet: hd.chiTiet }, { session });
    rows.push({ MaHoaDon: maHoaDon, MaCongTy: hd.maCongTy, TongTien: hd.tongTien });
  }
  return rows;
}

// 51401-51407: thanh toán đủ một lần cho hóa đơn.
async function thanhToanHoaDon(db, session, { invoiceId, amount, paymentDate, collector }) {
  if (!invoiceId || !amount || amount <= 0 || !paymentDate) throw businessError(51401);
  if (collector !== null && collector !== undefined && !collector.trim()) throw businessError(51404);
  const name = collector ? collector.trim() : null;
  const hd = await db.collection(COLLECTIONS.hoaDonThang.name).findOne({ maHoaDon: invoiceId }, { session });
  if (!hd) throw businessError(51402);
  if (hd.trangThai === "DA_THANH_TOAN") throw businessError(51403);
  if (paymentDate < hd.ngayLap || paymentDate > today()) throw businessError(51405);
  const total = money(hd.chiTiet.reduce((sum, l) => sum + l.soTien, 0));
  if (total <= 0 || money(amount) !== total) throw businessError(51406);
  const res = await db.collection(COLLECTIONS.hoaDonThang.name).updateOne(
    { _id: hd._id, trangThai: "CHUA_THANH_TOAN" },
    { $set: { trangThai: "DA_THANH_TOAN", ngayThanhToan: paymentDate, nguoiThu: name } }, { session });
  if (res.modifiedCount !== 1) throw businessError(51407);
  return [{ MaHoaDon: hd.maHoaDon, MaCongTy: hd.maCongTy, MaToaNha: hd.maToaNha, Thang: hd.thang, Nam: hd.nam,
    TrangThai: "DA_THANH_TOAN", NgayThanhToan: paymentDate, NguoiThu: name, SoTienDaThu: total }];
}

// 51501-51509: chốt bảng lương tháng của tòa (sau khi đã lập hóa đơn đủ các công ty).
async function chotBangLuong(db, session, { buildingId, month, year }) {
  if (!month || month < 1 || month > 12 || !year || year < 1900 || year > 9999) throw businessError(51501);
  await lockBuilding(db, session, buildingId);
  const building = await db.collection(COLLECTIONS.toaNha.name).findOne({ _id: buildingId }, { session });
  if (!building) throw businessError(51503);
  const invoices = await db.collection(COLLECTIONS.hoaDonThang.name).find({ maToaNha: buildingId, nam: year, thang: month }, { session }).toArray();
  if (!invoices.length) throw businessError(51502);
  const ctx = await loadContext(db, session, buildingId, year, month);
  const billed = new Set(invoices.map((h) => h.maCongTy));
  const active = new Set([...ctx.hopDong.map((h) => h.maCongTy), ...ctx.congTy.map((c) => c.maCongTy)]);
  if ([...active].some((c) => !billed.has(c))) throw businessError(51509);
  if (await db.collection(COLLECTIONS.bangLuong.name).findOne({ maToaNha: buildingId, nam: year, thang: month }, { session })) throw businessError(51503);

  const end = lastDay(year, month);
  const staff = building.nhanVien.filter((nv) => nv.ngayVaoLam <= end);
  const managers = staff.filter((nv) => nv.loai === "QUAN_LY");
  if (managers.length !== 1) throw businessError(51507);
  const phanCong = [];
  for (const nv of staff) {
    const pc = nv.phanCong.find((p) => p.thang === month && p.nam === year);
    if (!pc) throw businessError(51505);
    const bac = ctx.bacCongViec[pc.maBac];
    const serviceOk = nv.loai === "QUAN_LY" ? !pc.maDichVu : building.dichVu.some((d) => d.maDichVu === pc.maDichVu);
    if (!bac || bac.heSoDoanhThu < 0 || bac.heSoDoanhThu > 1 || bac.luongCoBan <= 0 || !serviceOk) throw businessError(51506);
    phanCong.push({ maNVTN: nv.maNVTN, maBac: pc.maBac, maDichVu: pc.maDichVu, luong: bac.luongCoBan });
  }
  if (!phanCong.length) throw businessError(51508);
  const rows = buildPayroll(phanCong, ctx.bacCongViec, invoices);
  await db.collection(COLLECTIONS.bangLuong.name).insertMany(rows.map((r) => ({ maToaNha: buildingId,
    maNVTN: r.maNVTN, nam: year, thang: month, luongCoBan: r.luongCoBan, tienThuong: r.tienThuong,
    maDichVu: r.maDichVu, maBac: r.maBac })), { session });
  return rows.map((r) => ({ MaNVTN: r.maNVTN, Thang: month, Nam: year, LuongCoBan: r.luongCoBan,
    TienThuong: r.tienThuong, TongLuong: money(r.luongCoBan + r.tienThuong) }));
}

const operations = {
  contract: (db, session, body) => ketHopDongThue(db, session, {
    companyId: body.companyId, buildingId: body.buildingId, startDate: body.startDate,
    endDate: body.endDate, officeIds: body.officeIds }),
  "daily-service": (db, session, body) => ghiNhatKyDichVu(db, session, body.items.map((i) => ({
    maNVCT: i.employeeId, maDichVu: i.serviceId, ngaySuDung: i.useDate, soLuot: i.quantity }))),
  invoice: (db, session, body) => lapHoaDonThang(db, session, { buildingId: body.buildingId, month: body.month, year: body.year }),
  payment: (db, session, body) => thanhToanHoaDon(db, session, { invoiceId: body.invoiceId, amount: body.amount,
    paymentDate: body.paymentDate, collector: body.collector }),
  payroll: (db, session, body) => chotBangLuong(db, session, { buildingId: body.buildingId, month: body.month, year: body.year })
};

// Chạy một nghiệp vụ trong transaction; trả về { operation, rows } như bản MySQL.
async function runTransaction(connection, name, body) {
  if (!Object.hasOwn(operations, name)) throw new ValidationError("Giao dịch không tồn tại.");
  const db = connection.db();
  const session = connection.client.startSession();
  let rows;
  try {
    await session.withTransaction(async () => {
      rows = await operations[name](db, session, body);
    }, { readConcern: { level: "snapshot" }, writeConcern: { w: "majority" } });
  } finally {
    await session.endSession();
  }
  return { operation: name, rows };
}

module.exports = { runTransaction, loadContext };
