const { ValidationError } = require("./errors");

const fields = {
  companies: { required: ["code", "name", "taxCode", "address", "sector"], optional: ["phone", "email"] },
  offices: { required: ["code", "buildingId", "locationId", "floor", "area"], optional: [] },
  contracts: { required: ["code", "companyId", "officeId", "startDate"], optional: ["endDate"] },
  services: { required: ["code", "buildingId", "serviceTypeId", "name", "basePrice"], optional: [] },
  employees: { required: ["type", "code", "name", "gender", "birthDate", "startDate"], optional: ["companyId", "buildingId", "managerId", "employeeType", "phone", "email", "jobTitle", "endDate"] }
};

const limits = { code: 20, name: 200, taxCode: 14, address: 300, sector: 100,
  phone: 20, email: 254, buildingId: 20, locationId: 20, companyId: 20,
  officeId: 20, serviceTypeId: 20, managerId: 20, jobTitle: 100 };

const validDate = (value) => /^\d{4}-\d{2}-\d{2}$/.test(value) && value.slice(0, 4) !== "0000" &&
  !Number.isNaN(Date.parse(`${value}T00:00:00Z`)) &&
  new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) === value;

function validateRecord(collection, body) {
  const schema = fields[collection];
  if (!schema || !body || typeof body !== "object" || Array.isArray(body)) throw new ValidationError("Dữ liệu không hợp lệ.");
  const allowed = new Set([...schema.required, ...schema.optional]);
  if (Object.keys(body).some((key) => !allowed.has(key))) throw new ValidationError("Biểu mẫu chứa trường không hợp lệ.");
  const record = {};
  for (const key of allowed) {
    const raw = body[key];
    if (raw === undefined || raw === null || raw === "") {
      if (schema.required.includes(key)) throw new ValidationError(`Thiếu ${key}.`);
      record[key] = null;
      continue;
    }
    if (["floor", "area", "basePrice"].includes(key)) {
      if (typeof raw !== "number" && (typeof raw !== "string" || !raw.trim())) throw new ValidationError(`${key} không hợp lệ.`);
      const value = Number(raw);
      if (!Number.isFinite(value) || (key === "floor" ? !Number.isInteger(value) || value < 1 || value > 32767 :
        key === "area" ? value <= 0 || value > 99999999.99 || Number(value.toFixed(2)) !== value :
        value < 0 || value > Number.MAX_SAFE_INTEGER / 100 || Number(value.toFixed(2)) !== value)) throw new ValidationError(`${key} không hợp lệ.`);
      record[key] = value;
    } else {
      if (typeof raw !== "string" || !raw.trim()) throw new ValidationError(`${key} không hợp lệ.`);
      const value = raw.trim();
      const maxLength = key === "name" ? { services: 120, employees: 150, companies: 200 }[collection] : limits[key];
      if (maxLength && value.length > maxLength) throw new ValidationError(`${key} quá dài.`);
      if (key.endsWith("Date") && !validDate(value)) throw new ValidationError(`${key} không phải ngày hợp lệ.`);
      record[key] = value;
    }
  }
  if (!/^[A-Za-z0-9_-]{1,20}$/.test(record.code)) throw new ValidationError("Mã chỉ gồm chữ, số, _ và - (tối đa 20 ký tự).");
  if (record.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(record.email)) throw new ValidationError("Email không hợp lệ.");
  if (collection === "companies" && !/^(\d{10}|\d{10}-\d{3})$/.test(record.taxCode)) throw new ValidationError("Mã số thuế phải gồm 10 chữ số hoặc 10-3 chữ số.");
  if (collection === "services" && record.basePrice <= 0) throw new ValidationError("Đơn giá dịch vụ phải lớn hơn 0.");
  if (collection === "contracts" && record.endDate && record.endDate < record.startDate) throw new ValidationError("Ngày kết thúc không thể trước ngày bắt đầu.");
  if (collection === "employees") {
    if (!["company", "building"].includes(record.type)) throw new ValidationError("Loại nhân viên không hợp lệ.");
    if (record.type === "company") {
      if (!record.companyId || !record.jobTitle || record.buildingId || record.managerId || record.employeeType) throw new ValidationError("Nhân viên công ty cần công ty và chức vụ.");
    } else if (!record.buildingId || !["QUAN_LY", "DICH_VU"].includes(record.employeeType) || record.companyId || record.jobTitle || record.endDate ||
      (record.employeeType === "QUAN_LY" ? record.managerId : !record.managerId || record.managerId === record.code)) {
      throw new ValidationError("Nhân viên tòa nhà cần tòa, loại nhân viên và quản lý phù hợp.");
    }
    if (!["M", "F", "O"].includes(record.gender)) throw new ValidationError("Giới tính không hợp lệ.");
    if (!(record.birthDate < record.startDate)) throw new ValidationError("Ngày sinh phải trước ngày vào làm.");
    if (record.endDate && record.endDate < record.startDate) throw new ValidationError("Ngày nghỉ không thể trước ngày vào làm.");
  }
  return record;
}

module.exports = { fields, validateRecord };

