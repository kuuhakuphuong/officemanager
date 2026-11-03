const sql = require("mssql");
const { ValidationError } = require("./sql-store");

const procedures = {
  contract: "USP_Trx_KyHopDongThueMatBang",
  "daily-service": "USP_Trx_GhiNhanDichVuHangNgay",
  invoice: "USP_Trx_PhatHanhHoaDonThang",
  // TV6 sửa: thanh toán đủ hóa đơn trên 18 bảng; giữ tên procedure TV4 để tương thích.
  payment: "USP_Trx_ThanhToanHoaDonVaVaoSoQuy",
  payroll: "USP_Trx_ChotBangLuongNhanVien"
};

const paymentMessage = "Procedure thanh toán TV4 còn là bản cũ (51400); hãy cài lại 03_Transactions.sql. Không có phiếu thu/sổ quỹ độc lập.";

const messages = {
  51000: "Procedure phải được gọi ngoài transaction của ứng dụng.",
  51001: "Không lấy được khóa nghiệp vụ. Hãy thử lại.",
  51101: "Ngày thuê hoặc danh sách phòng không hợp lệ.",
  51102: "Công ty hoặc tòa nhà không tồn tại.",
  51103: "Văn phòng không tồn tại hoặc không thuộc tòa nhà đã chọn.",
  51105: "Khoảng thuê trùng với kỳ đã có hóa đơn.",
  51106: "Có văn phòng trùng lịch thuê. Toàn bộ lô đã được hủy.",
  51201: "Lô rỗng, số lượt không hợp lệ hoặc ngày sử dụng trong tương lai.",
  51202: "Nhân viên, dịch vụ, đăng ký hoặc hợp đồng không hợp lệ vào ngày sử dụng.",
  51203: "Không thể ghi nhật ký vào kỳ đã phát hành hóa đơn.",
  51204: "Lô có nhật ký đã được ghi nhận. Không cộng dồn ngầm.",
  51301: "Tháng hoặc năm không hợp lệ.",
  51302: "Chỉ phát hành hóa đơn khi tháng đã kết thúc.",
  51303: "Tòa nhà không tồn tại.",
  51304: "Kỳ đã có hóa đơn. Không ghi đè hoặc lập bổ sung ngầm.",
  51305: "Thiếu hoặc sai tham số bậc thang.",
  51306: "Dữ liệu hợp đồng nguồn bị chồng lịch.",
  51307: "Đăng ký dịch vụ tháng có ngày không có hợp đồng thuê cùng tòa.",
  51308: "Kỳ không có khoản thu để lập hóa đơn.",
  51401: "Mã hóa đơn, số tiền và ngày thanh toán không hợp lệ.",
  51402: "Hóa đơn không tồn tại.",
  51403: "Hóa đơn đã được thanh toán.",
  51404: "Tên người thu không được để toàn khoảng trắng.",
  51405: "Ngày thanh toán phải từ ngày lập hóa đơn đến hôm nay.",
  51406: "Số tiền phải khớp đúng tổng hóa đơn; chỉ hỗ trợ trả đủ một lần.",
  51407: "Không cập nhật được trạng thái thanh toán.",
  51501: "Tháng hoặc năm không hợp lệ.",
  51502: "Phải phát hành hóa đơn tòa nhà trước khi chốt lương.",
  51503: "Kỳ đã có lương. Không tính lại hoặc ghi đè.",
  51505: "Có nhân viên chưa được phân công trong tháng.",
  51506: "Phân công, bậc lương hoặc dịch vụ không hợp lệ.",
  51507: "Tòa nhà phải có đúng một quản lý trong tháng.",
  51508: "Không có nhân viên để tính lương.",
  51509: "Còn công ty chưa được lập hóa đơn trong kỳ."
};

function exactKeys(value, keys, label) {
  if (!value || typeof value !== "object" || Array.isArray(value) ||
      Object.keys(value).some((key) => !keys.includes(key)))
    throw new ValidationError(`${label} không hợp lệ.`);
}

function code(value, label) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,20}$/.test(value))
    throw new ValidationError(`${label} phải là mã 1–20 ký tự.`);
  return value;
}

function date(value, label, optional = false) {
  if (optional && (value === null || value === "" || value === undefined)) return null;
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value) || Number(value.slice(0, 4)) < 1 ||
      Number.isNaN(Date.parse(`${value}T00:00:00Z`)) ||
      new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) !== value)
    throw new ValidationError(`${label} phải là ngày YYYY-MM-DD hợp lệ.`);
  return value;
}

function integer(value, label, min, max) {
  if (!Number.isInteger(value) || value < min || value > max)
    throw new ValidationError(`${label} phải là số nguyên từ ${min} đến ${max}.`);
  return value;
}

function batch(value, label) {
  if (!Array.isArray(value) || value.length < 1 || value.length > 200)
    throw new ValidationError(`${label} phải có từ 1 đến 200 dòng.`);
  return value;
}

function validateTransaction(name, body) {
  if (!Object.hasOwn(procedures, name)) return null;
  // TV6 sửa: kiểm tra dữ liệu thanh toán ở API; procedure tiếp tục kiểm tra số tiền đúng với hóa đơn.
  if (name === "payment") {
    exactKeys(body, ["invoiceId", "amount", "paymentDate", "collector"], "Thanh toán hóa đơn");
    const invoiceId = integer(body.invoiceId, "Mã hóa đơn", 1, 2147483647);
    if (typeof body.amount !== "number" || !Number.isFinite(body.amount) || body.amount <= 0 ||
        body.amount > 9999999999999999 || !Number.isSafeInteger(Math.round(body.amount * 100)) ||
        Math.abs(body.amount * 100 - Math.round(body.amount * 100)) > 1e-7)
      throw new ValidationError("Số tiền phải dương và có tối đa hai chữ số thập phân.");
    const paymentDate = date(body.paymentDate, "Ngày thanh toán");
    const collector = typeof body.collector === "string" ? body.collector.trim() : null;
    if (body.collector !== undefined && body.collector !== null &&
        (!collector || collector.length > 100))
      throw new ValidationError("Người thu phải có từ 1 đến 100 ký tự hoặc để trống.");
    return { invoiceId, amount: body.amount, paymentDate, collector };
  }
  if (name === "contract") {
    exactKeys(body, ["companyId", "buildingId", "startDate", "endDate", "officeIds"], "Giao dịch thuê");
    const officeIds = batch(body.officeIds, "Danh sách văn phòng").map((id) => code(id, "Mã văn phòng"));
    if (new Set(officeIds).size !== officeIds.length) throw new ValidationError("Danh sách văn phòng có mã trùng.");
    const startDate = date(body.startDate, "Ngày bắt đầu");
    const endDate = date(body.endDate, "Ngày kết thúc", true);
    // TV6 sửa: ngày bắt đầu và kết thúc trùng nhau là hợp lệ.
    if (endDate && endDate < startDate) throw new ValidationError("Ngày kết thúc không được trước ngày bắt đầu.");
    return { companyId: code(body.companyId, "Mã công ty"), buildingId: code(body.buildingId, "Mã tòa nhà"), startDate, endDate, officeIds };
  }
  if (name === "daily-service") {
    exactKeys(body, ["items"], "Giao dịch dịch vụ");
    const items = batch(body.items, "Danh sách sử dụng").map((item) => {
      exactKeys(item, ["employeeId", "serviceId", "useDate", "quantity"], "Dòng sử dụng");
      return { employeeId: code(item.employeeId, "Mã nhân viên"), serviceId: code(item.serviceId, "Mã dịch vụ"),
        useDate: date(item.useDate, "Ngày sử dụng"), quantity: integer(item.quantity, "Số lượt", 1, 2147483647) };
    });
    const keys = items.map((item) => `${item.employeeId}\0${item.serviceId}\0${item.useDate}`);
    if (new Set(keys).size !== keys.length) throw new ValidationError("Danh sách sử dụng có dòng trùng nhân viên, dịch vụ và ngày.");
    return { items };
  }
  exactKeys(body, ["buildingId", "month", "year"], "Giao dịch theo kỳ");
  return { buildingId: code(body.buildingId, "Mã tòa nhà"), month: integer(body.month, "Tháng", 1, 12),
    year: integer(body.year, "Năm", 1900, 9999) };
}

async function executeTransaction(store, name, body) {
  const values = validateTransaction(name, body);
  const request = (await store.pool()).request();
  if (name === "contract") {
    const rooms = new sql.Table("dbo.TT_DanhSachPhong");
    rooms.columns.add("MaVanPhong", sql.VarChar(20), { nullable: false });
    for (const id of values.officeIds) rooms.rows.add(id);
    request.input("MaCongTy", sql.VarChar(20), values.companyId);
    request.input("MaToaNha", sql.VarChar(20), values.buildingId);
    request.input("NgayBatDau", sql.Date, values.startDate);
    request.input("NgayKetThuc", sql.Date, values.endDate);
    request.input("DanhSachPhong", rooms);
  } else if (name === "daily-service") {
    const uses = new sql.Table("dbo.TT_DanhSachSuDung");
    uses.columns.add("MaNVCT", sql.VarChar(20), { nullable: false });
    uses.columns.add("MaDichVu", sql.VarChar(20), { nullable: false });
    uses.columns.add("NgaySuDung", sql.Date, { nullable: false });
    uses.columns.add("SoLuot", sql.Int, { nullable: false });
    for (const item of values.items) uses.rows.add(item.employeeId, item.serviceId, item.useDate, item.quantity);
    request.input("DanhSach", uses);
  } else if (name === "payment") {
    // TV6 sửa: MaYeuCau không gửi vì schema 18 bảng không lưu khóa idempotency.
    request.input("MaHoaDon", sql.Int, values.invoiceId);
    request.input("SoTien", sql.Decimal(18, 2), values.amount);
    request.input("NgayThanhToan", sql.Date, values.paymentDate);
    request.input("NguoiThu", sql.NVarChar(100), values.collector);
  } else {
    request.input("MaToaNha", sql.VarChar(20), values.buildingId);
    request.input("Thang", sql.TinyInt, values.month);
    request.input("Nam", sql.SmallInt, values.year);
  }
  const result = await request.execute(`dbo.${procedures[name]}`);
  if (!result.recordset?.length) throw new Error(`Procedure ${procedures[name]} không trả dữ liệu kết quả.`);
  return { procedure: procedures[name], rows: result.recordset };
}

function tv4Error(error) {
  const number = Number(error?.number ?? error?.originalError?.info?.number);
  if (!Number.isInteger(number) || number < 51000 || number > 51999) return null;
  return { code: String(number), message: number === 51400 ? paymentMessage : messages[number] || error.message };
}

module.exports = { validateTransaction, executeTransaction, tv4Error, paymentMessage };
