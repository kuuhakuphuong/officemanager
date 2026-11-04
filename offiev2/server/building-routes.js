// Route trang "Quản lý toà nhà". File mới: không thay đổi route cũ.
// GET  /api/buildings/manage              -> toà nhà, nhân sự theo toà, dịch vụ và đơn giá, tham số, đơn giá thuê m² theo vị trí
// PUT  /api/buildings/:id                 -> sửa tên, địa chỉ, số tầng của toà
// PUT  /api/buildings/services/:id/price  -> sửa đơn giá cơ bản của dịch vụ
// PUT  /api/buildings/parameters/:name    -> sửa giá trị tham số dùng chung
// PUT  /api/buildings/locations/:id/price -> sửa đơn giá thuê m² theo vị trí (dùng chung toàn hệ thống)
const { ValidationError } = require("./sql-store");

function requireSql(sqlStore, response) {
  if (sqlStore) return true;
  response.status(503).json({ code: "DATABASE_REQUIRED", message: "Trang quản lý toà nhà cần MySQL." });
  return false;
}

function positiveNumber(value, label) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) throw new ValidationError(`${label} phải là số lớn hơn 0.`);
  return number;
}

function registerBuildingRoutes(app, sqlStore) {
  app.get("/api/buildings/manage", async (_, response, next) => {
    if (!requireSql(sqlStore, response)) return;
    try {
      const [buildings, staff, services, parameters, locations] = await Promise.all([
        sqlStore.query("SELECT MaToaNha AS id, TenToaNha AS name, DiaChi AS address, SoTang AS floors FROM ToaNha ORDER BY MaToaNha"),
        sqlStore.query(`SELECT nv.MaNVTN AS id, nv.MaToaNha AS buildingId, nv.LoaiNV AS employeeType, nv.HoTen AS name,
          nv.MaQuanLy AS managerId, ql.HoTen AS managerName
          FROM NhanVienToaNha nv LEFT JOIN NhanVienToaNha ql ON ql.MaNVTN = nv.MaQuanLy
          ORDER BY nv.MaToaNha, nv.LoaiNV, nv.HoTen`),
        sqlStore.query(`SELECT dv.MaDichVu AS id, dv.MaToaNha AS buildingId, dv.TenDichVu AS name,
          lo.TenLoai AS serviceType, dv.DonGiaCoBan AS basePrice
          FROM DichVu dv JOIN LoaiDichVu lo ON lo.MaLoaiDV = dv.MaLoaiDV ORDER BY dv.MaToaNha, dv.MaDichVu`),
        sqlStore.query("SELECT TenThamSo AS name, GiaTri AS value, MoTa AS description FROM ThamSo ORDER BY TenThamSo"),
        sqlStore.query("SELECT MaViTri AS id, TenViTri AS name, DonGiaThueM2 AS pricePerM2 FROM ViTri ORDER BY MaViTri")
      ]);
      return response.json({ buildings, staff, services, parameters, locations });
    } catch (error) { return next(error); }
  });

  // Tạo toà nhà mới: mã tự sinh theo dãy TNxx (TN01, TN02, ... theo mã lớn nhất hiện có).
  app.post("/api/buildings", async (request, response, next) => {
    if (!requireSql(sqlStore, response)) return;
    try {
      const name = String(request.body?.name || "").trim();
      const address = String(request.body?.address || "").trim();
      if (!name || !address) throw new ValidationError("Tên và địa chỉ toà nhà không được để trống.");
      const floors = Math.trunc(positiveNumber(request.body?.floors, "Số tầng"));
      const existing = await sqlStore.query("SELECT MaToaNha AS id FROM ToaNha");
      const next = existing.reduce((max, row) => Math.max(max, Number(String(row.id).replace(/\D/g, "")) || 0), 0) + 1;
      const id = `TN${String(next).padStart(2, "0")}`;
      await sqlStore.query("INSERT INTO ToaNha (MaToaNha, TenToaNha, DiaChi, SoTang) VALUES (@id, @name, @address, @floors)",
        { id, name, address, floors });
      return response.status(201).json({ id, name, address, floors });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/:id", async (request, response, next) => {
    if (!requireSql(sqlStore, response)) return;
    try {
      const name = String(request.body?.name || "").trim();
      const address = String(request.body?.address || "").trim();
      if (!name || !address) throw new ValidationError("Tên và địa chỉ toà nhà không được để trống.");
      const floors = Math.trunc(positiveNumber(request.body?.floors, "Số tầng"));
      const result = await sqlStore.query(
        "UPDATE ToaNha SET TenToaNha = @name, DiaChi = @address, SoTang = @floors WHERE MaToaNha = @id",
        { id: request.params.id, name, address, floors });
      if (!result.affectedRows) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy toà nhà." });
      return response.json({ id: request.params.id, name, address, floors });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/services/:id/price", async (request, response, next) => {
    if (!requireSql(sqlStore, response)) return;
    try {
      const price = positiveNumber(request.body?.basePrice, "Đơn giá cơ bản");
      const result = await sqlStore.query("UPDATE DichVu SET DonGiaCoBan = @price WHERE MaDichVu = @id",
        { id: request.params.id, price });
      if (!result.affectedRows) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy dịch vụ." });
      return response.json({ id: request.params.id, basePrice: price });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/parameters/:name", async (request, response, next) => {
    if (!requireSql(sqlStore, response)) return;
    try {
      const value = Number(request.body?.value);
      if (!Number.isFinite(value) || value < 0) throw new ValidationError("Giá trị tham số phải là số không âm.");
      const result = await sqlStore.query("UPDATE ThamSo SET GiaTri = @value WHERE TenThamSo = @name",
        { name: request.params.name, value });
      if (!result.affectedRows) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy tham số." });
      return response.json({ name: request.params.name, value });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/locations/:id/price", async (request, response, next) => {
    if (!requireSql(sqlStore, response)) return;
    try {
      const pricePerM2 = positiveNumber(request.body?.pricePerM2, "Đơn giá thuê m²");
      const result = await sqlStore.query("UPDATE ViTri SET DonGiaThueM2 = @pricePerM2 WHERE MaViTri = @id",
        { id: request.params.id, pricePerM2 });
      if (!result.affectedRows) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy vị trí." });
      return response.json({ id: request.params.id, pricePerM2 });
    } catch (error) { return next(error); }
  });
}

module.exports = { registerBuildingRoutes };
