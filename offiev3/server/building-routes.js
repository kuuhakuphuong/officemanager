// Route trang "Quản lý toà nhà" cho MongoDB. File mới: không thay đổi route cũ.
// GET  /api/buildings/manage              -> toà nhà, nhân sự theo toà, dịch vụ và đơn giá, tham số, đơn giá thuê m² theo vị trí
// PUT  /api/buildings/:id                 -> sửa tên, địa chỉ, số tầng của toà
// PUT  /api/buildings/services/:id/price  -> sửa đơn giá cơ bản của dịch vụ (phần tử mảng dichVu trong toà)
// PUT  /api/buildings/parameters/:name    -> sửa giá trị tham số dùng chung (collection thong_so)
// PUT  /api/buildings/locations/:id/price -> sửa đơn giá thuê m² theo vị trí (collection vi_tri)
// Mọi lệnh ghi đều lọc theo _id của toà (khóa phân mảnh maToaNha) để không cần quét nhiều shard.
const { ValidationError } = require("./errors");

function positiveNumber(value, label) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) throw new ValidationError(`${label} phải là số lớn hơn 0.`);
  return number;
}

function registerBuildingRoutes(app, mongoStore) {
  // Chế độ cục bộ không có MongoDB: không đăng ký route, trang sẽ báo cần MongoDB.
  if (!mongoStore) return;

  app.get("/api/buildings/manage", async (_, response, next) => {
    try {
      const [buildingDocs, categories, parameterDocs, locationDocs] = await Promise.all([
        mongoStore.col("toaNha").find({}, { projection: { tenToaNha: 1, diaChi: 1, soTang: 1, dichVu: 1, nhanVien: 1 } }).sort({ _id: 1 }).toArray(),
        mongoStore.col("loaiDichVu").find({}).toArray(),
        mongoStore.col("thongSo").find({}).sort({ _id: 1 }).toArray(),
        mongoStore.col("viTri").find({}).sort({ _id: 1 }).toArray()
      ]);
      const typeName = new Map(categories.map((row) => [row._id, row.tenLoai]));
      const managerName = new Map(buildingDocs.flatMap((b) => b.nhanVien.map((nv) => [nv.maNVTN, nv.hoTen])));
      return response.json({
        buildings: buildingDocs.map((b) => ({ id: b._id, name: b.tenToaNha, address: b.diaChi, floors: b.soTang })),
        staff: buildingDocs.flatMap((b) => b.nhanVien.map((nv) => ({
          id: nv.maNVTN, buildingId: b._id, employeeType: nv.loai, name: nv.hoTen,
          managerId: nv.maQuanLy || null, managerName: managerName.get(nv.maQuanLy) || null
        }))),
        services: buildingDocs.flatMap((b) => b.dichVu.map((dv) => ({
          id: dv.maDichVu, buildingId: b._id, name: dv.tenDichVu,
          serviceType: typeName.get(dv.maLoaiDV) || dv.maLoaiDV, basePrice: dv.donGiaCoBan
        }))),
        parameters: parameterDocs.map((p) => ({ name: p._id, value: p.giaTri, description: p.moTa })),
        locations: locationDocs.map((v) => ({ id: v._id, name: v.tenViTri, pricePerM2: v.donGiaThueM2 }))
      });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/:id", async (request, response, next) => {
    try {
      const name = String(request.body?.name || "").trim();
      const address = String(request.body?.address || "").trim();
      if (!name || !address) throw new ValidationError("Tên và địa chỉ toà nhà không được để trống.");
      const floors = Math.trunc(positiveNumber(request.body?.floors, "Số tầng"));
      const result = await mongoStore.col("toaNha").updateOne({ _id: request.params.id },
        { $set: { tenToaNha: name, diaChi: address, soTang: floors } });
      if (!result.matchedCount) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy toà nhà." });
      return response.json({ id: request.params.id, name, address, floors });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/services/:id/price", async (request, response, next) => {
    try {
      const price = positiveNumber(request.body?.basePrice, "Đơn giá cơ bản");
      const building = await mongoStore.col("toaNha").findOne({ "dichVu.maDichVu": request.params.id }, { projection: { _id: 1 } });
      if (!building) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy dịch vụ." });
      await mongoStore.col("toaNha").updateOne({ _id: building._id, "dichVu.maDichVu": request.params.id },
        { $set: { "dichVu.$.donGiaCoBan": price } });
      return response.json({ id: request.params.id, basePrice: price });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/parameters/:name", async (request, response, next) => {
    try {
      const value = Number(request.body?.value);
      if (!Number.isFinite(value) || value < 0) throw new ValidationError("Giá trị tham số phải là số không âm.");
      const result = await mongoStore.col("thongSo").updateOne({ _id: request.params.name }, { $set: { giaTri: value } });
      if (!result.matchedCount) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy tham số." });
      return response.json({ name: request.params.name, value });
    } catch (error) { return next(error); }
  });

  app.put("/api/buildings/locations/:id/price", async (request, response, next) => {
    try {
      const pricePerM2 = positiveNumber(request.body?.pricePerM2, "Đơn giá thuê m²");
      const result = await mongoStore.col("viTri").updateOne({ _id: request.params.id }, { $set: { donGiaThueM2: pricePerM2 } });
      if (!result.matchedCount) return response.status(404).json({ code: "NOT_FOUND", message: "Không tìm thấy vị trí." });
      return response.json({ id: request.params.id, pricePerM2 });
    } catch (error) { return next(error); }
  });
}

module.exports = { registerBuildingRoutes };
