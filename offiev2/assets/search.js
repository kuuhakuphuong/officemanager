// Tìm kiếm và lọc danh sách vận hành. Dùng chung cho trình duyệt (app.js) và máy chủ (server/index.js).
// - q: tìm theo chuỗi con, không phân biệt hoa thường và không phân biệt dấu tiếng Việt
//   ("thang long" khớp "Thăng Long").
// - Các tham số còn lại: lọc bằng đúng giá trị của một trường (eq), hoặc `active` cho hiệu lực hợp đồng.
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.searchUtils = api;
})(typeof self !== "undefined" ? self : globalThis, function () {
  const norm = (value) => String(value ?? "")
    .normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/đ/g, "d").replace(/Đ/g, "D")
    .toLowerCase().trim();

  // Trường được tìm bằng q, theo từng danh mục.
  const SEARCH_FIELDS = {
    companies: ["id", "name", "taxCode", "sector"],
    offices: ["code", "building", "location"],
    contracts: ["code", "company", "officeId"],
    services: ["code", "name", "building", "serviceType"],
    employees: ["code", "name", "email", "company", "building", "jobTitle"]
  };

  // Tham số lọc theo đúng giá trị một trường.
  const FILTERS = {
    companies: { sector: "sector" },
    offices: { buildingId: "buildingId", locationId: "locationId", status: "status" },
    contracts: { companyId: "companyId", officeId: "officeId", active: "active" },
    services: { buildingId: "buildingId", serviceTypeId: "serviceTypeId" },
    employees: { type: "type", companyId: "companyId", buildingId: "buildingId", employeeType: "employeeType" }
  };

  const today = () => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  };

  function filterRows(collection, rows, params = {}) {
    const q = norm(params.q);
    const fields = SEARCH_FIELDS[collection] || [];
    const filters = FILTERS[collection] || {};
    return rows.filter((row) => {
      if (q && !fields.some((field) => norm(row[field]).includes(q))) return false;
      for (const [param, field] of Object.entries(filters)) {
        const value = params[param];
        if (value === undefined || value === null || value === "") continue;
        if (param === "active") {
          const now = today();
          const live = row.startDate <= now && (!row.endDate || row.endDate >= now);
          if ((String(value) === "1") !== live) return false;
          continue;
        }
        if (String(row[field] ?? "") !== String(value)) return false;
      }
      return true;
    });
  }

  return { filterRows, norm, SEARCH_FIELDS, FILTERS };
});
