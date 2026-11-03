// Kiểm tra dữ liệu đầu vào cho giao dịch TV4 (không phụ thuộc CSDL).
// Giữ nguyên quy tắc của bản MySQL để hợp đồng API không đổi.
const { ValidationError } = require("./errors");

const transactionNames = ["contract", "daily-service", "invoice", "payment", "payroll"];

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
  if (!transactionNames.includes(name)) return null;
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

module.exports = { validateTransaction, transactionNames };
