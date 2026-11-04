// Route trang "Quản lý toà nhà" cho SQL Server. File mới: không thay đổi route cũ.
// GET  /api/buildings/manage              -> toà nhà, nhân sự theo toà, dịch vụ và đơn giá, tham số, đơn giá thuê m² theo vị trí
// PUT  /api/buildings/:id                 -> sửa tên, địa chỉ, số tầng của toà
// PUT  /api/buildings/services/:id/price  -> sửa đơn giá cơ bản của dịch vụ
// PUT  /api/buildings/parameters/:name    -> sửa giá trị tham số dùng chung
// PUT  /api/buildings/locations/:id/price -> sửa đơn giá thuê m² theo vị trí (dùng chung toàn hệ thống)
const { ValidationError } = require("./sql-store");

function positiveNumber(value, label) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) throw new ValidationError(`${label} phải là số lớn hơn 0.`);
  return number;
}

function registerBuildingRoutes(app, sqlStore) {
  // Chế độ cục bộ không có SQL Server: không đăng ký route, trang sẽ báo cần SQL Server.
  if (!sqlStore) return;
  const { VarChar, NVarChar, SmallInt, Decimal } = sqlStore.driver;

  // inputs: [tên tham số, kiểu SQL Server, giá trị]
  async function run(text, inputs = []) {
    const request = (await sqlStore.pool()).request();
    for (const [name, type, value] of inputs) request.input(name, type, value);
    return request.query(text);
  }

  app.get("/api/buildings/manage", async (_, response, next) => {
    try {
      const [buildings, staff, services, parameters, locations] = await Promise.all([
        run("SELECT MaToaNha AS id, TenToaNha AS name, DiaChi AS address, SoTang AS floors FROM dbo.ToaNha ORDER BY MaToaNha"),
        run(`SELECT nv.MaNVTN AS id, nv.MaToaNha AS buildingId, nv.LoaiNV AS employeeType, nv.HoTen AS name,
          nv.MaQuanLy AS managerId, ql.HoTen AS managerName
          FROM dbo.NhanVienToaNha nv LEFT JOIN dbo.NhanVienToaNha ql ON ql.MaNVTN = nv.MaQuanLy
          ORDER BY nv.MaToaNha, nv.LoaiNV, nv.HoTen`),
        run(`SELECT dv.MaDichVu AS id, dv.MaToaNha AS buildingId, dv.TenDichVu AS name,
          lo.TenLoai AS serviceType, dv.DonGiaCoBan AS basePrice
          FROM dbo.DichVu dv JOIN dbo.LoaiDichVu lo ON lo.MaLoaiDV = dv.MaLoaiDV ORDER BY dv.MaToaNha, dv.MaDichVu`),
        run("SELECT TenThamSo AS name, GiaTri AS value, MoTa AS description FROM dbo.ThamSo ORDER BY TenThamSo"),
        run("SELECT MaViTri AS id, TenViTri AS name, DonGiaThueM2 AS pricePerM2 FROM dbo.ViTri ORDER BY MaViTri")
      ]);
      return response.json({
        buildings: buildings.recordset, staff: staff.recordset, services: services.recordset,
        parameters: parameters.recordset, locations: locations.recordset
      });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/:id", async (request, response, next) => {
    try {
      const name = String(request.body?.name || "").trim();
      const address = String(request.body?.address || "").trim();
      if (!name || !address) throw new ValidationError("Tên và địa chỉ toà nhà không được để trống.");
      const floors = Math.trunc(positiveNumber(request.body?.floors, "Số tầng"));
      const result = await run("UPDATE dbo.ToaNha SET TenToaNha = @name, DiaChi = @address, SoTang = @floors WHERE MaToaNha = @id",
        [["id", VarChar(20), request.params.id], ["name", NVarChar(150), name], ["address", NVarChar(300), address], ["floors", SmallInt, floors]]);
      if (!result.rowsAffected[0]) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy toà nhà." });
      return response.json({ id: request.params.id, name, address, floors });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/services/:id/price", async (request, response, next) => {
    try {
      const price = positiveNumber(request.body?.basePrice, "Đơn giá cơ bản");
      const result = await run("UPDATE dbo.DichVu SET DonGiaCoBan = @price WHERE MaDichVu = @id",
        [["id", VarChar(20), request.params.id], ["price", Decimal(18, 2), price]]);
      if (!result.rowsAffected[0]) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy dịch vụ." });
      return response.json({ id: request.params.id, basePrice: price });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/parameters/:name", async (request, response, next) => {
    try {
      const value = Number(request.body?.value);
      if (!Number.isFinite(value) || value < 0) throw new ValidationError("Giá trị tham số phải là số không âm.");
      const result = await run("UPDATE dbo.ThamSo SET GiaTri = @value WHERE TenThamSo = @name",
        [["name", VarChar(50), request.params.name], ["value", Decimal(18, 6), value]]);
      if (!result.rowsAffected[0]) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy tham số." });
      return response.json({ name: request.params.name, value });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/locations/:id/price", async (request, response, next) => {
    try {
      const pricePerM2 = positiveNumber(request.body?.pricePerM2, "Đơn giá thuê m²");
      const result = await run("UPDATE dbo.ViTri SET DonGiaThueM2 = @pricePerM2 WHERE MaViTri = @id",
        [["id", VarChar(20), request.params.id], ["pricePerM2", Decimal(18, 2), pricePerM2]]);
      if (!result.rowsAffected[0]) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy vị trí." });
      return response.json({ id: request.params.id, pricePerM2 });
    } catch (error) { return next(error); }
  });
}

module.exports = { registerBuildingRoutes };
