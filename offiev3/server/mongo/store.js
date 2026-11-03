// Kho dữ liệu MongoDB: CRUD danh mục, tra cứu, báo cáo (aggregation) và trạng thái cụm.
// Hình dạng bản ghi trả về giữ nguyên như bản MySQL để giao diện không đổi.
const { ValidationError, businessError } = require("../errors");
const { COLLECTIONS, buildingCollections } = require("./collections");
const { money, ymd, inRange } = require("./billing");
const { MongoConnection } = require("./connection");
const { runTransaction } = require("./transactions");

const FAR = "9999-12-31";
const today = () => { const d = new Date(); return ymd(d.getFullYear(), d.getMonth() + 1, d.getDate()); };
const amount = (value) => Number(value || 0);
const periodText = (year, month) => `${year}-${String(month).padStart(2, "0")}`;

function reportFilters(name, query) {
  const allowed = {
    "company-cost": { companyId: "code", buildingId: "code", from: "month", to: "month" },
    "daily-services": { companyId: "code", buildingId: "code", employeeId: "code", serviceType: "code", from: "date", to: "date" },
    payroll: { buildingId: "code", period: "month" },
    "building-cashflow": { buildingId: "code", from: "date", to: "date" }
  }[name];
  if (!allowed) throw new ValidationError("Báo cáo không tồn tại.");
  const result = {};
  for (const key of Object.keys(query)) if (!Object.hasOwn(allowed, key)) throw new ValidationError(`Bộ lọc ${key} không hợp lệ.`);
  for (const [key, type] of Object.entries(allowed)) {
    const value = query[key];
    if (value === undefined || value === "") { result[key] = null; continue; }
    if (typeof value !== "string") throw new ValidationError(`Bộ lọc ${key} không hợp lệ.`);
    if (type === "code" && !/^[\w-]{1,20}$/.test(value)) throw new ValidationError(`Mã ${key} không hợp lệ.`);
    if (type === "month" && !/^(19\d{2}|[2-9]\d{3})-(0[1-9]|1[0-2])$/.test(value)) throw new ValidationError(`Tháng ${key} không hợp lệ.`);
    if (type === "date" && !/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new ValidationError(`Ngày ${key} không hợp lệ.`);
    result[key] = value;
  }
  if (result.from && result.to && result.from > result.to) throw new ValidationError("Khoảng thời gian không hợp lệ.");
  return result;
}

function summarize(rows, keys, chartKey, chartValue = "amount") {
  const points = new Map();
  for (const row of rows) points.set(row[chartKey], (points.get(row[chartKey]) || 0) + Math.round(amount(row[chartValue]) * 100));
  return {
    summary: keys,
    chart: [...points].sort(([a], [b]) => String(a).localeCompare(String(b))).map(([label, cents]) => ({ label, value: cents / 100 })),
    rows,
    total: rows.length
  };
}

const moneySum = (rows, select = (row) => row.amount) =>
  rows.reduce((cents, row) => cents + Math.round(amount(select(row)) * 100), 0) / 100;

class MongoStore {
  constructor(connection = new MongoConnection()) {
    this.connection = connection;
  }

  async connect() {
    await this.connection.connect();
    return this;
  }

  db() { return this.connection.db(); }
  col(key) { return this.db().collection(COLLECTIONS[key].name); }

  async close() { await this.connection.close(); }

  // Tên và hình dạng bản ghi công ty/tòa nhà đều được nạp một lần cho tra cứu và báo cáo.
  async directory() {
    const [buildings, companies, services, loai, bac] = await Promise.all([
      this.col("toaNha").find({}, { projection: { vanPhong: 1, dichVu: 1, nhanVien: 1, tenToaNha: 1, soTang: 1 } }).toArray(),
      this.col("congTy").find({}, { projection: { dichVuDangKy: 0 } }).toArray(),
      this.col("viTri").find({}).toArray(),
      this.col("loaiDichVu").find({}).toArray(),
      this.col("bacCongViec").find({}).toArray()
    ]);
    return {
      buildings: new Map(buildings.map((b) => [b._id, b])),
      companies: new Map(companies.map((c) => [c.maCongTy, c])),
      locations: new Map(services.map((v) => [v._id, v.tenViTri])),
      serviceTypes: new Map(loai.map((l) => [l._id, l])),
      grades: new Map(bac.map((b) => [b._id, b]))
    };
  }

  async health() {
    const cluster = await this.clusterStatus().catch(() => null);
    const names = (await this.db().listCollections({}, { nameOnly: true }).toArray()).map((c) => c.name);
    const expected = Object.values(COLLECTIONS).map((c) => c.name);
    const missing = expected.filter((name) => !names.includes(name));
    if (missing.length) {
      const error = new Error(`MongoDB thiếu collection: ${missing.join(", ")}`);
      error.code = "SCHEMA_MISMATCH";
      throw error;
    }
    return { status: "ok", dataMode: "mongo", database: this.connection.config.database, schema: "MONGO-SHARDED-10",
      readOnly: false, transactionsReady: true, paymentReady: true,
      shards: cluster ? cluster.shards.length : 0 };
  }

  // Trạng thái cụm: số shard, tag zone và số bản ghi mỗi shard cho các collection theo tòa nhà.
  // Số bản ghi lấy bằng $group thực tế (không dùng $collStats/estimatedDocumentCount: đó là số metadata
  // và có thể đếm dư khi còn bản ghi mồ côi sau migration). Ánh xạ tòa -> shard qua tag zone.
  async clusterStatus() {
    const admin = this.connection.client.db("admin");
    const { shards } = await admin.command({ listShards: 1 });
    const tags = await this.connection.client.db("config").collection("shards").find({}).toArray();
    const zoneToShard = {};
    for (const t of tags) for (const tag of t.tags || []) zoneToShard[tag] = t._id;
    const placement = {};
    for (const col of buildingCollections()) {
      const groups = await this.db().collection(col.name).aggregate([
        { $group: { _id: "$maToaNha", documents: { $sum: 1 } } },
        { $sort: { _id: 1 } }
      ]).toArray();
      placement[col.name] = Object.fromEntries(groups.map((g) => [g._id, { shard: zoneToShard[g._id] || null, documents: g.documents }]));
    }
    return {
      shards: shards.map((s) => ({ id: s._id, host: s.host, tags: tags.find((t) => t._id === s._id)?.tags || [] })),
      placement
    };
  }

  async lookups() {
    const [buildings, locations, types, companies, emps, offices, managers, unpaid] = await Promise.all([
      this.col("toaNha").find({}, { projection: { tenToaNha: 1, soTang: 1 } }).sort({ tenToaNha: 1 }).toArray(),
      this.col("viTri").find({}).sort({ tenViTri: 1 }).toArray(),
      this.col("loaiDichVu").find({}).sort({ tenLoai: 1 }).toArray(),
      this.col("congTy").find({}, { projection: { tenCongTy: 1 } }).sort({ tenCongTy: 1 }).toArray(),
      this.col("nhanVienCongTy").find({}).sort({ hoTen: 1, _id: 1 }).toArray(),
      this.col("toaNha").find({}).toArray(),
      this.col("toaNha").find({}).toArray(),
      this.col("hoaDonThang").find({ trangThai: "CHUA_THANH_TOAN" }).sort({ maHoaDon: 1 }).toArray()
    ]);
    const buildingsById = new Map(buildings.map((b) => [b._id, b]));
    const companiesById = new Map(companies.map((c) => [c._id, c]));
    return {
      buildings: buildings.map((b) => ({ id: b._id, name: b.tenToaNha, floors: b.soTang })),
      locations: locations.map((v) => ({ id: v._id, name: v.tenViTri })),
      serviceTypes: types.map((l) => ({ id: l._id, name: l.tenLoai, billingType: l.kieuTinhPhi })),
      companies: companies.map((c) => ({ id: c._id, name: c.tenCongTy })),
      companyEmployees: emps.map((e) => ({ id: e._id, name: e.hoTen, companyId: e.maCongTy })),
      offices: offices.flatMap((b) => b.vanPhong.map((v) => ({ id: v.maVanPhong, name: v.maVanPhong, buildingId: b._id }))),
      managers: managers.flatMap((b) => b.nhanVien.filter((nv) => nv.loai === "QUAN_LY")
        .map((nv) => ({ id: nv.maNVTN, name: nv.hoTen, buildingId: b._id }))),
      unpaidInvoices: unpaid.map((h) => ({ id: h.maHoaDon,
        name: `${companiesById.get(h.maCongTy)?.tenCongTy || h.maCongTy} · ${buildingsById.get(h.maToaNha)?.tenToaNha || h.maToaNha} · ${h.thang}/${h.nam}`,
        amount: money(h.tongTien) }))
    };
  }

  // Danh sách theo collection, giữ nguyên hình dạng như bản MySQL.
  // params: bộ lọc từ query string. Các điều kiện bằng nhau và khoảng ngày được đẩy xuống DB (có chỉ mục);
  // tìm chuỗi (q) và phần nhúng được lọc trong bộ nhớ ở tầng index.js.
  async list(collection, params = {}) {
    const dir = await this.directory();
    if (collection === "companies") {
      const rows = await this.col("congTy").find(companyQuery(params)).sort({ _id: 1 }).toArray();
      return rows.map((c) => ({ id: c._id, code: c._id, name: c.tenCongTy, taxCode: c.maSoThue, address: c.diaChi,
        phone: c.dienThoai, email: c.email, sector: c.linhVuc }));
    }
    if (collection === "offices") {
      const now = today();
      const active = new Set((await this.col("hopDongThue").find({ ngayBatDau: { $lte: now },
        $or: [{ ngayKetThuc: null }, { ngayKetThuc: { $gte: now } }] }, { projection: { maVanPhong: 1 } }).toArray())
        .map((h) => h.maVanPhong));
      return [...dir.buildings.values()].flatMap((b) => b.vanPhong.map((v) => ({
        id: v.maVanPhong, code: v.maVanPhong, buildingId: b._id, building: b.tenToaNha,
        locationId: v.maViTri, location: dir.locations.get(v.maViTri) || "", floor: v.tang, area: v.dienTich,
        status: active.has(v.maVanPhong) ? "DANG_THUE" : "TRONG" }))).sort((a, b) => a.code.localeCompare(b.code));
    }
    if (collection === "contracts") {
      const rows = await this.col("hopDongThue").find(contractQuery(params)).sort({ _id: 1 }).toArray();
      return rows.map((h) => ({ id: h.maHopDong, code: h.maHopDong, companyId: h.maCongTy,
        company: dir.companies.get(h.maCongTy)?.tenCongTy || "", officeId: h.maVanPhong,
        startDate: h.ngayBatDau, endDate: h.ngayKetThuc || null }));
    }
    if (collection === "services") {
      return [...dir.buildings.values()].flatMap((b) => b.dichVu.map((d) => ({ id: d.maDichVu, code: d.maDichVu,
        buildingId: b._id, building: b.tenToaNha, serviceTypeId: d.maLoaiDV,
        serviceType: dir.serviceTypes.get(d.maLoaiDV)?.tenLoai || "", name: d.tenDichVu, basePrice: d.donGiaCoBan })))
        .sort((a, b) => a.code.localeCompare(b.code));
    }
    // employees: nhân viên công ty + nhân viên tòa nhà (nhúng trong tài liệu tòa nhà).
    // Nhân viên công ty không có tòa/loại nhân viên: bỏ qua khi lọc theo các trường chỉ có ở nhân viên tòa.
    const includeCompany = (!params.type || params.type === "company") && !(params.buildingId || params.employeeType);
    const companyRows = includeCompany ? await this.col("nhanVienCongTy").find(employeeQuery(params)).sort({ _id: 1 }).toArray() : [];
    const companyStaff = companyRows.map((nv) => ({
      id: `CT:${nv._id}`, type: "company", code: nv._id, name: nv.hoTen, gender: nv.gioiTinh, birthDate: nv.ngaySinh,
      phone: nv.dienThoai, email: nv.email, startDate: nv.ngayVaoLam, endDate: nv.ngayNghiViec || null,
      companyId: nv.maCongTy, company: dir.companies.get(nv.maCongTy)?.tenCongTy || "", buildingId: null, building: "",
      managerId: null, employeeType: null, jobTitle: nv.chucVu }));
    const buildingStaff = [...dir.buildings.values()].flatMap((b) => b.nhanVien.map((nv) => ({
      id: `TN:${nv.maNVTN}`, type: "building", code: nv.maNVTN, name: nv.hoTen, gender: nv.gioiTinh, birthDate: nv.ngaySinh,
      phone: nv.dienThoai, email: nv.email, startDate: nv.ngayVaoLam, endDate: null, companyId: null, company: "",
      buildingId: b._id, building: b.tenToaNha, managerId: nv.maQuanLy || null, employeeType: nv.loai, jobTitle: null })));
    return [...buildingStaff, ...companyStaff].sort((a, b) => a.type.localeCompare(b.type) || a.code.localeCompare(b.code));
  }

  // ----------------------------------------------------------------- ghi dữ liệu
  async write(collection, record, originalId = null) {
    if (collection === "companies") return this.writeCompany(record, originalId);
    if (collection === "offices") return this.writeOffice(record, originalId);
    if (collection === "contracts") return this.writeContract(record, originalId);
    if (collection === "services") return this.writeService(record, originalId);
    if (collection === "employees") return this.writeEmployee(record, originalId);
    throw new ValidationError("Danh mục không tồn tại.");
  }

  async writeCompany(record, originalId) {
    const doc = { tenCongTy: record.name, maSoThue: record.taxCode, diaChi: record.address,
      dienThoai: record.phone, email: record.email, linhVuc: record.sector };
    if (originalId) {
      if (record.code !== originalId) throw new ValidationError("Không thể đổi mã hoặc loại nhân viên của bản ghi.");
      const res = await this.col("congTy").updateOne({ _id: originalId }, { $set: doc });
      if (!res.matchedCount) return null;
    } else {
      await this.col("congTy").insertOne({ _id: record.code, maCongTy: record.code, ...doc, dichVuDangKy: [] });
    }
    return (await this.list("companies")).find((row) => row.id === record.code);
  }

  async writeOffice(record, originalId) {
    const target = await this.col("toaNha").findOne({ _id: record.buildingId });
    if (!target) throw new ValidationError("Tòa nhà không tồn tại.");
    if (record.floor > target.soTang) throw new ValidationError("Tầng văn phòng phải thuộc tòa nhà đã chọn.");
    const location = await this.col("viTri").findOne({ _id: record.locationId });
    if (!location) throw new ValidationError("Vị trí không tồn tại.");
    const office = { maVanPhong: record.code, maViTri: record.locationId, tang: record.floor, dienTich: record.area };
    if (!originalId) {
      if (await this.col("toaNha").findOne({ "vanPhong.maVanPhong": record.code })) throw businessError(11000, "Mã văn phòng đã tồn tại.");
      await this.col("toaNha").updateOne({ _id: record.buildingId }, { $push: { vanPhong: office } });
    } else {
      const current = await this.col("toaNha").findOne({ "vanPhong.maVanPhong": originalId });
      if (!current) return null;
      if (current._id === record.buildingId) {
        await this.col("toaNha").updateOne({ _id: current._id, "vanPhong.maVanPhong": originalId },
          { $set: { "vanPhong.$.maViTri": office.maViTri, "vanPhong.$.tang": office.tang, "vanPhong.$.dienTich": office.dienTich } });
      } else {
        await this.col("toaNha").updateOne({ _id: current._id }, { $pull: { vanPhong: { maVanPhong: originalId } } });
        await this.col("toaNha").updateOne({ _id: record.buildingId }, { $push: { vanPhong: office } });
      }
    }
    return (await this.list("offices")).find((row) => row.id === record.code);
  }

  async writeContract(record, originalId) {
    const building = await this.col("toaNha").findOne({ "vanPhong.maVanPhong": record.officeId });
    if (!building) throw new ValidationError("Văn phòng không tồn tại.");
    if (!originalId) {
      await runTransaction(this.connection, "contract", { companyId: record.companyId, buildingId: building._id,
        startDate: record.startDate, endDate: record.endDate, officeIds: [record.officeId] }).then((r) => r.rows[0]);
      const created = await this.col("hopDongThue").findOne({ maVanPhong: record.officeId, maCongTy: record.companyId,
        ngayBatDau: record.startDate }, { sort: { _id: -1 } });
      return (await this.list("contracts")).find((row) => row.id === created.maHopDong);
    }
    const current = await this.col("hopDongThue").findOne({ _id: originalId });
    if (!current) return null;
    const changed = ["maCongTy", "maVanPhong", "ngayBatDau", "ngayKetThuc"].some((k) => {
      const incoming = { maCongTy: record.companyId, maVanPhong: record.officeId, ngayBatDau: record.startDate, ngayKetThuc: record.endDate || null }[k];
      return (current[k] || null) !== (incoming || null);
    });
    if (changed) {
      await this.assertNoInvoiceLock(building._id, [current, { maCongTy: record.companyId, maVanPhong: record.officeId,
        ngayBatDau: record.startDate, ngayKetThuc: record.endDate || null }], originalId);
      await this.assertNoOverlap(record.officeId, record.startDate, record.endDate || null, originalId);
    }
    await this.col("hopDongThue").updateOne({ _id: originalId }, { $set: { maCongTy: record.companyId,
      maVanPhong: record.officeId, maToaNha: building._id, ngayBatDau: record.startDate, ngayKetThuc: record.endDate || null } });
    return (await this.list("contracts")).find((row) => row.id === originalId);
  }

  // 51105: không sửa/xóa hợp đồng ảnh hưởng kỳ đã lập hóa đơn.
  async assertNoInvoiceLock(buildingId, periods, exceptId) {
    const invoices = await this.col("hoaDonThang").find({ maToaNha: buildingId }).toArray();
    for (const p of periods) {
      const end = p.ngayKetThuc || FAR;
      const hit = invoices.some((hd) => {
        const first = ymd(hd.nam, hd.thang, 1);
        const last = ymd(hd.nam, hd.thang, new Date(Date.UTC(hd.nam, hd.thang, 0)).getUTCDate());
        return p.maCongTy === hd.maCongTy && first <= end && last >= p.ngayBatDau;
      });
      if (hit) throw businessError(51105, "Kỳ đã lập hóa đơn; không thể thay đổi hợp đồng ảnh hưởng kỳ này.");
    }
    void exceptId;
  }

  async assertNoOverlap(officeId, start, end, exceptId) {
    const overlap = await this.col("hopDongThue").findOne({ _id: { $ne: exceptId }, maVanPhong: officeId,
      ngayBatDau: { $lte: end || FAR }, $or: [{ ngayKetThuc: null }, { ngayKetThuc: { $gte: start } }] });
    if (overlap) throw new ValidationError("Văn phòng đã có hợp đồng trong khoảng thời gian này.");
  }

  async writeService(record, originalId) {
    const type = await this.col("loaiDichVu").findOne({ _id: record.serviceTypeId });
    if (!type) throw new ValidationError("Loại dịch vụ không tồn tại.");
    const doc = { maLoaiDV: record.serviceTypeId, tenDichVu: record.name, donGiaCoBan: record.basePrice };
    const building = await this.col("toaNha").findOne({ _id: record.buildingId });
    if (!building) throw new ValidationError("Tòa nhà không tồn tại.");
    if (!originalId) {
      if (await this.col("toaNha").findOne({ "dichVu.maDichVu": record.code })) throw businessError(11000, "Mã dịch vụ đã tồn tại.");
      await this.col("toaNha").updateOne({ _id: record.buildingId }, { $push: { dichVu: { maDichVu: record.code, ...doc } } });
    } else {
      const res = await this.col("toaNha").updateOne({ _id: record.buildingId, "dichVu.maDichVu": originalId },
        { $set: { "dichVu.$.maLoaiDV": doc.maLoaiDV, "dichVu.$.tenDichVu": doc.tenDichVu, "dichVu.$.donGiaCoBan": doc.donGiaCoBan } });
      if (!res.matchedCount) return null;
    }
    return (await this.list("services")).find((row) => row.id === record.code);
  }

  async writeEmployee(record, originalId) {
    if (record.type === "company") {
      const doc = { maCongTy: record.companyId, hoTen: record.name, gioiTinh: record.gender, ngaySinh: record.birthDate,
        dienThoai: record.phone, email: record.email, chucVu: record.jobTitle, ngayVaoLam: record.startDate, ngayNghiViec: record.endDate };
      if (originalId) {
        const res = await this.col("nhanVienCongTy").updateOne({ _id: record.code }, { $set: doc });
        if (!res.matchedCount) return null;
      } else {
        await this.col("nhanVienCongTy").insertOne({ _id: record.code, ...doc });
      }
      return (await this.list("employees")).find((row) => row.id === `CT:${record.code}`);
    }
    const building = await this.col("toaNha").findOne({ _id: record.buildingId });
    if (!building) throw new ValidationError("Tòa nhà không tồn tại.");
    const staff = { maNVTN: record.code, hoTen: record.name, gioiTinh: record.gender, ngaySinh: record.birthDate,
      dienThoai: record.phone, email: record.email, ngayVaoLam: record.startDate, loai: record.employeeType,
      maQuanLy: record.managerId || null, phanCong: [] };
    if (!originalId) {
      await this.col("toaNha").updateOne({ _id: record.buildingId }, { $push: { nhanVien: staff } });
    } else {
      const res = await this.col("toaNha").updateOne({ _id: record.buildingId, "nhanVien.maNVTN": originalId },
        { $set: { "nhanVien.$.hoTen": staff.hoTen, "nhanVien.$.gioiTinh": staff.gioiTinh, "nhanVien.$.ngaySinh": staff.ngaySinh,
          "nhanVien.$.dienThoai": staff.dienThoai, "nhanVien.$.email": staff.email, "nhanVien.$.ngayVaoLam": staff.ngayVaoLam,
          "nhanVien.$.loai": staff.loai, "nhanVien.$.maQuanLy": staff.maQuanLy } });
      if (!res.matchedCount) return null;
    }
    return (await this.list("employees")).find((row) => row.id === `TN:${record.code}`);
  }

  // ----------------------------------------------------------------- xóa dữ liệu
  async remove(collection, id) {
    if (collection === "companies") {
      const phuThuoc = await Promise.all([
        this.col("hopDongThue").countDocuments({ maCongTy: id }),
        this.col("nhanVienCongTy").countDocuments({ maCongTy: id }),
        this.col("hoaDonThang").countDocuments({ maCongTy: id }),
        this.col("congTy").countDocuments({ _id: id, "dichVuDangKy.0": { $exists: true } })
      ]);
      if (phuThuoc.some((n) => n > 0)) throw businessError(55401);
      return Boolean((await this.col("congTy").deleteOne({ _id: id })).deletedCount);
    }
    if (collection === "contracts") {
      const hd = await this.col("hopDongThue").findOne({ _id: id });
      if (!hd) return false;
      await this.assertNoInvoiceLock(hd.maToaNha, [hd], id);
      return Boolean((await this.col("hopDongThue").deleteOne({ _id: id })).deletedCount);
    }
    if (collection === "offices") {
      const used = await this.col("hopDongThue").countDocuments({ maVanPhong: id });
      if (used) throw businessError(55403, "Không thể xóa văn phòng vì còn hợp đồng liên quan.");
      const res = await this.col("toaNha").updateOne({ "vanPhong.maVanPhong": id }, { $pull: { vanPhong: { maVanPhong: id } } });
      return Boolean(res.modifiedCount);
    }
    if (collection === "services") {
      const used = await this.col("nhatKySuDung").countDocuments({ maDichVu: id });
      if (used) throw businessError(55404, "Không thể xóa dịch vụ vì đã có nhật ký sử dụng.");
      const res = await this.col("toaNha").updateOne({ "dichVu.maDichVu": id }, { $pull: { dichVu: { maDichVu: id } } });
      return Boolean(res.modifiedCount);
    }
    if (collection === "employees") {
      const [type, code] = id.split(":");
      if (type === "CT") return Boolean((await this.col("nhanVienCongTy").deleteOne({ _id: code })).deletedCount);
      const res = await this.col("toaNha").updateOne({ "nhanVien.maNVTN": code }, { $pull: { nhanVien: { maNVTN: code } } });
      return Boolean(res.modifiedCount);
    }
    throw new ValidationError("Danh mục không tồn tại.");
  }

  // ----------------------------------------------------------------- báo cáo (aggregation)
  async report(name, query) {
    const filters = reportFilters(name, query);
    const dir = await this.directory();
    if (name === "company-cost") {
      const match = {};
      if (filters.companyId) match.maCongTy = filters.companyId;
      if (filters.buildingId) match.maToaNha = filters.buildingId;
      const invoices = await this.col("hoaDonThang").aggregate([
        { $match: match },
        { $unwind: "$chiTiet" },
        { $sort: { nam: 1, thang: 1, maHoaDon: 1 } }
      ]).toArray();
      const rows = invoices.filter((r) => inPeriod(r, filters.from, filters.to)).map((r) => {
        const l = r.chiTiet;
        return { period: periodText(r.nam, r.thang), company: dir.companies.get(r.maCongTy)?.tenCongTy || r.maCongTy,
          building: dir.buildings.get(r.maToaNha)?.tenToaNha || r.maToaNha, invoice: r.maHoaDon,
          contract: "", category: l.loaiKhoan, categoryLabel: CATEGORY[l.loaiKhoan] || l.loaiKhoan,
          item: l.maVanPhong || serviceName(dir, r.maToaNha, l.maDichVu), quantity: amount(l.soLuong),
          unitPrice: amount(l.donGiaApDung), dayRatio: amount(l.tyLeNgay), amount: amount(l.soTien) };
      });
      return summarize(rows, {
        totalCost: moneySum(rows),
        rentCost: moneySum(rows, (r) => r.category === "THUE_VAN_PHONG" ? r.amount : 0),
        serviceCost: moneySum(rows, (r) => r.category.startsWith("DICH_VU_") ? r.amount : 0),
        monthlyServiceCost: moneySum(rows, (r) => r.category === "DICH_VU_THANG" ? r.amount : 0),
        usageServiceCost: moneySum(rows, (r) => r.category === "DICH_VU_LUOT" ? r.amount : 0),
        invoiceCount: new Set(rows.map((r) => r.invoice)).size
      }, "period");
    }
    if (name === "daily-services") {
      const match = {};
      if (filters.buildingId) match.maToaNha = filters.buildingId;
      if (filters.companyId) match.maCongTy = filters.companyId;
      if (filters.employeeId) match.maNVCT = filters.employeeId;
      if (filters.from || filters.to) match.ngaySuDung = { ...(filters.from && { $gte: filters.from }), ...(filters.to && { $lte: filters.to }) };
      const logs = await this.col("nhatKySuDung").aggregate([{ $match: match }, { $sort: { ngaySuDung: 1, _id: 1 } }]).toArray();
      const employees = new Map((await this.col("nhanVienCongTy").find({}).toArray()).map((nv) => [nv._id, nv]));
      const rows = logs.filter((log) => !filters.serviceType || serviceType(dir, log.maToaNha, log.maDichVu) === filters.serviceType)
        .map((log) => {
          const nv = employees.get(log.maNVCT);
          const dv = serviceOf(dir, log.maToaNha, log.maDichVu);
          return { id: String(log._id), date: log.ngaySuDung, company: dir.companies.get(log.maCongTy)?.tenCongTy || "",
            building: dir.buildings.get(log.maToaNha)?.tenToaNha || "", employee: nv?.hoTen || log.maNVCT,
            employeeId: log.maNVCT, service: dv?.tenDichVu || "", serviceType: dir.serviceTypes.get(dv?.maLoaiDV)?.tenLoai || "",
            quantity: log.soLuot, unitPrice: amount(log.donGiaApDung), amount: money(log.soLuot * log.donGiaApDung), maLoai: dv?.maLoaiDV };
        });
      return summarize(rows.map(({ maLoai, ...r }) => r), {
        totalUses: rows.reduce((sum, r) => sum + r.quantity, 0),
        totalCost: moneySum(rows),
        mealUses: rows.reduce((sum, r) => sum + (r.maLoai === "AN_UONG" ? r.quantity : 0), 0),
        parkingUses: rows.reduce((sum, r) => sum + (r.maLoai === "GUI_XE" ? r.quantity : 0), 0)
      }, "date");
    }
    if (name === "payroll") {
      const match = {};
      if (filters.buildingId) match.maToaNha = filters.buildingId;
      const bangLuong = await this.col("bangLuong").find(match).sort({ nam: 1, thang: 1, maNVTN: 1 }).toArray();
      const filtered = bangLuong.filter((r) => !filters.period || periodText(r.nam, r.thang) === filters.period);
      const staff = new Map([...dir.buildings.values()].flatMap((b) => b.nhanVien.map((nv) => [nv.maNVTN, { nv, tenToa: b.tenToaNha }])));
      const invoices = await this.col("hoaDonThang").find(filters.buildingId ? { maToaNha: filters.buildingId } : {}).toArray();
      const revenue = invoices.filter((h) => !filters.period || periodText(h.nam, h.thang) === filters.period)
        .flatMap((h) => h.chiTiet).filter((l) => ["DICH_VU_THANG", "DICH_VU_LUOT"].includes(l.loaiKhoan))
        .reduce((sum, l) => sum + l.soTien, 0);
      const rows = filtered.map((r) => ({ period: periodText(r.nam, r.thang), employeeId: r.maNVTN,
        employee: staff.get(r.maNVTN)?.nv.hoTen || r.maNVTN, building: staff.get(r.maNVTN)?.tenToa || "",
        role: dir.grades.get(r.maBac)?.tenBac || r.maBac, service: serviceName(dir, r.maToaNha, r.maDichVu) || "",
        baseSalary: amount(r.luongCoBan), bonus: amount(r.tienThuong), amount: money(r.luongCoBan + r.tienThuong) }));
      const totalPayroll = moneySum(rows);
      return summarize(rows, { totalPayroll, basePayroll: moneySum(rows, (r) => r.baseSalary),
        totalBonus: moneySum(rows, (r) => r.bonus), employeeCount: new Set(rows.map((r) => r.employeeId)).size,
        averagePayroll: rows.length ? totalPayroll / rows.length : 0, serviceRevenue: money(revenue) }, "period");
    }
    // building-cashflow
    const bMatch = { trangThai: "DA_THANH_TOAN" };
    if (filters.buildingId) bMatch.maToaNha = filters.buildingId;
    const paid = (await this.col("hoaDonThang").find(bMatch).toArray()).filter((h) => inRange(h.ngayThanhToan, filters.from || "0000-01-01", filters.to || FAR));
    const costs = await this.col("chiPhiVanHanh").find(filters.buildingId ? { maToaNha: filters.buildingId } : {}).toArray();
    const payroll = await this.col("bangLuong").find(filters.buildingId ? { maToaNha: filters.buildingId } : {}).toArray();
    const rows = [
      ...paid.map((h) => ({ date: h.ngayThanhToan, period: periodText(h.nam, h.thang),
        building: dir.buildings.get(h.maToaNha)?.tenToaNha || h.maToaNha, type: "Thu", reference: `Hóa đơn #${h.maHoaDon}`,
        counterparty: dir.companies.get(h.maCongTy)?.tenCongTy || h.maCongTy, description: "Hóa đơn đã thanh toán",
        dateBasis: "Ngày thanh toán", amount: money(h.tongTien) })),
      ...costs.filter((c) => inRange(ymd(c.nam, c.thang, 1), filters.from || "0000-01-01", filters.to || FAR)).map((c) => ({
        date: ymd(c.nam, c.thang, 1), period: periodText(c.nam, c.thang), building: dir.buildings.get(c.maToaNha)?.tenToaNha || "",
        type: "Chi", reference: `Chi phí #${c._id}`, counterparty: null, description: c.loaiChiPhi, dateBasis: "Đầu kỳ kế toán", amount: -c.soTien })),
      ...payroll.filter((p) => inRange(ymd(p.nam, p.thang, 1), filters.from || "0000-01-01", filters.to || FAR)).map((p) => ({
        date: ymd(p.nam, p.thang, 1), period: periodText(p.nam, p.thang), building: dir.buildings.get(p.maToaNha)?.tenToaNha || "",
        type: "Chi", reference: `Lương ${p.maNVTN}`, counterparty: null, description: "Lương tháng", dateBasis: "Đầu kỳ kế toán",
        amount: -money(p.luongCoBan + p.tienThuong) }))
    ].sort((a, b) => a.date.localeCompare(b.date) || a.type.localeCompare(b.type) || a.reference.localeCompare(b.reference));
    const totalIncome = moneySum(rows, (r) => Math.max(0, r.amount));
    const totalExpense = moneySum(rows, (r) => Math.max(0, -r.amount));
    return summarize(rows, { totalIncome, totalExpense, netCashflow: Math.round((totalIncome - totalExpense) * 100) / 100,
      entryCount: rows.length }, "date");
  }
}

// Điều kiện lọc trong DB. Chỉ dùng đúng các trường đã có chỉ mục (xem database/seed/seed.js).
function companyQuery(p) { return p.sector ? { linhVuc: String(p.sector) } : {}; }
function employeeQuery(p) { return p.companyId ? { maCongTy: String(p.companyId) } : {}; }
function contractQuery(p) {
  const and = [];
  if (p.companyId) and.push({ maCongTy: String(p.companyId) });
  if (p.officeId) and.push({ maVanPhong: String(p.officeId) });
  const now = today();
  if (p.active === "1") and.push({ ngayBatDau: { $lte: now }, $or: [{ ngayKetThuc: null }, { ngayKetThuc: { $gte: now } }] });
  if (p.active === "0") and.push({ $or: [{ ngayBatDau: { $gt: now } }, { ngayKetThuc: { $lt: now } }] });
  return and.length ? { $and: and } : {};
}

const CATEGORY = { THUE_VAN_PHONG: "Thuê văn phòng", DICH_VU_THANG: "Dịch vụ tháng", DICH_VU_LUOT: "Dịch vụ theo lượt" };
const serviceOf = (dir, buildingId, maDichVu) => dir.buildings.get(buildingId)?.dichVu.find((d) => d.maDichVu === maDichVu);
const serviceName = (dir, buildingId, maDichVu) => serviceOf(dir, buildingId, maDichVu)?.tenDichVu || "";
const serviceType = (dir, buildingId, maDichVu) => serviceOf(dir, buildingId, maDichVu)?.maLoaiDV;
const inPeriod = (row, from, to) => {
  const period = periodText(row.nam, row.thang);
  return (!from || period >= from) && (!to || period <= to);
};

module.exports = { MongoStore, reportFilters };
