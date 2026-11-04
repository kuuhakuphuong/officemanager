(() => {
  "use strict";

  const config = { apiBase: (window.APP_CONFIG?.apiBase || "").replace(/\/$/, "") };
  const main = document.querySelector("main");
  const nav = document.querySelector("#navigation");
  const title = document.querySelector("#page-title");
  const breadcrumb = document.querySelector("#breadcrumb");
  const storageKey = "office-chain-manager:v1";
  const schemas = {
    companies: {
      title: "Công ty", fields: [
        ["code", "Mã công ty"], ["name", "Tên công ty"], ["taxCode", "Mã số thuế"],
        ["address", "Địa chỉ"], ["phone", "Điện thoại", "tel", false],
        ["email", "Email", "email", false], ["sector", "Lĩnh vực"]
      ], columns: [["code", "Mã"], ["name", "Tên công ty"], ["taxCode", "Mã số thuế"], ["address", "Địa chỉ"], ["sector", "Lĩnh vực"]]
    },
    offices: {
      title: "Văn phòng", fields: [
        ["code", "Mã văn phòng"], ["buildingId", "Tòa nhà", "buildings"],
        ["locationId", "Vị trí", "locations"], ["floor", "Tầng", "number"], ["area", "Diện tích (m²)", "number"]
      ], columns: [["code", "Mã"], ["building", "Tòa nhà"], ["location", "Vị trí"], ["floor", "Tầng"], ["area", "Diện tích (m²)"], ["status", "Trạng thái"]]
    },
    contracts: {
      title: "Hợp đồng", fields: [
        ["code", "Mã hợp đồng"], ["companyId", "Công ty", "companies"], ["officeId", "Văn phòng", "offices"],
        ["startDate", "Ngày bắt đầu", "date"], ["endDate", "Ngày kết thúc", "date", false]
      ], columns: [["code", "Mã"], ["company", "Công ty"], ["officeId", "Văn phòng"], ["startDate", "Từ ngày"], ["endDate", "Đến ngày"]]
    },
    services: {
      title: "Dịch vụ", fields: [
        ["code", "Mã dịch vụ"], ["buildingId", "Tòa nhà", "buildings"],
        ["serviceTypeId", "Loại dịch vụ", "serviceTypes"], ["name", "Tên dịch vụ"], ["basePrice", "Đơn giá cơ bản (VND)", "number"]
      ], columns: [["code", "Mã"], ["building", "Tòa nhà"], ["serviceType", "Loại dịch vụ"], ["name", "Tên"], ["basePrice", "Đơn giá"]]
    },
    employees: {
      title: "Nhân viên", fields: [
        ["type", "Thuộc", "employeeKinds"], ["code", "Mã nhân viên"], ["name", "Họ và tên"],
        ["gender", "Giới tính", "genders"], ["birthDate", "Ngày sinh", "date"],
        ["phone", "Điện thoại", "tel", false], ["email", "Email", "email", false],
        ["startDate", "Ngày vào làm", "date"]
      ], columns: [["type", "Thuộc"], ["code", "Mã"], ["name", "Họ tên"], ["company", "Công ty"], ["building", "Tòa nhà"], ["employeeType", "Loại NV"], ["jobTitle", "Chức vụ"]]
    }
  };
  const reports = {
    "company-cost": { title: "Chi phí công ty", description: "Chi phí hóa đơn theo kỳ, công ty và tòa nhà.", endpoint: "company-cost", chart: "line", filters: [["companyId", "Công ty", "companies"], ["buildingId", "Tòa nhà", "buildings"], ["from", "Từ tháng", "month"], ["to", "Đến tháng", "month"]], metrics: [["Tổng chi phí", "totalCost"], ["Tiền thuê", "rentCost"], ["Dịch vụ tháng", "monthlyServiceCost"], ["Dịch vụ theo lượt", "usageServiceCost"], ["Số hóa đơn", "invoiceCount", false]], columns: [["period", "Kỳ tính"], ["company", "Công ty"], ["building", "Tòa nhà"], ["invoice", "Hóa đơn"], ["contract", "Hợp đồng"], ["categoryLabel", "Loại khoản"], ["item", "Văn phòng / dịch vụ"], ["quantity", "Số lượng"], ["unitPrice", "Đơn giá"], ["dayRatio", "Tỷ lệ ngày"], ["amount", "Thành tiền"]] },
    "daily-services": { title: "Chi tiết dịch vụ ngày", description: "Lượt sử dụng và đơn giá chốt theo ngày.", endpoint: "daily-services", chart: "bar", filters: [["companyId", "Công ty", "companies"], ["buildingId", "Tòa nhà", "buildings"], ["employeeId", "Nhân viên", "companyEmployees"], ["serviceType", "Loại dịch vụ", "serviceTypes"], ["from", "Từ ngày", "date"], ["to", "Đến ngày", "date"]], metrics: [["Tổng lượt", "totalUses", false], ["Tổng tiền", "totalCost"], ["Ăn uống", "mealUses", false], ["Gửi xe", "parkingUses", false]], columns: [["date", "Ngày"], ["company", "Công ty"], ["building", "Tòa nhà"], ["employee", "Nhân viên"], ["employeeId", "Mã NV"], ["service", "Dịch vụ"], ["quantity", "Số lượt"], ["unitPrice", "Đơn giá"], ["amount", "Thành tiền"]] },
    payroll: { title: "Bảng lương", description: "Lương cơ bản và thưởng đã chốt theo kỳ.", endpoint: "payroll", chart: "bar", filters: [["buildingId", "Tòa nhà", "buildings"], ["period", "Kỳ lương", "month"]], metrics: [["Tổng quỹ lương", "totalPayroll"], ["Lương cơ bản", "basePayroll"], ["Tổng thưởng", "totalBonus"], ["Số nhân viên", "employeeCount", false], ["Lương bình quân / dòng", "averagePayroll"], ["Doanh thu dịch vụ hóa đơn", "serviceRevenue"]], columns: [["period", "Kỳ lương"], ["building", "Tòa nhà"], ["employeeId", "Mã NV"], ["employee", "Nhân viên"], ["role", "Bậc công việc"], ["service", "Dịch vụ phân công"], ["baseSalary", "Lương cơ bản"], ["bonus", "Thưởng"], ["amount", "Thực nhận"]] },
    // TV6 sửa: dòng báo cáo là tham chiếu hóa đơn/khoản chi, không phải chứng từ thu độc lập.
    "building-cashflow": { title: "Thu chi toàn tòa nhà", description: "Thu theo ngày thanh toán; chi theo đầu kỳ kế toán vì CSDL chưa lưu ngày chi thực tế.", endpoint: "building-cashflow", chart: "line", filters: [["buildingId", "Tòa nhà", "buildings"], ["from", "Từ ngày", "date"], ["to", "Đến ngày", "date"]], metrics: [["Tổng thu thực nhận", "totalIncome"], ["Tổng chi ghi nhận", "totalExpense"], ["Chênh lệch", "netCashflow"], ["Số dòng thu/chi", "entryCount", false]], columns: [["date", "Ngày thu / mốc kỳ chi"], ["dateBasis", "Cơ sở ngày"], ["period", "Kỳ gốc"], ["building", "Tòa nhà"], ["type", "Loại"], ["reference", "Tham chiếu"], ["counterparty", "Đối tượng"], ["description", "Diễn giải"], ["amount", "Số tiền"]] }
  };
  const transactions = [
    ["contract", "Ký hợp đồng thuê mặt bằng", "USP_Trx_KyHopDongThueMatBang"],
    ["daily-service", "Ghi nhận dịch vụ hằng ngày", "USP_Trx_GhiNhanDichVuHangNgay"],
    ["invoice", "Phát hành hóa đơn tháng", "USP_Trx_PhatHanhHoaDonThang"],
    // TV6 sửa: tên procedure giữ nguyên, nhưng nghiệp vụ 18 bảng chỉ ghi thanh toán đủ hóa đơn.
    ["payment", "Ghi nhận thanh toán đủ hóa đơn", "USP_Trx_ThanhToanHoaDonVaVaoSoQuy"],
    ["payroll", "Chốt bảng lương nhân viên", "USP_Trx_ChotBangLuongNhanVien"]
  ];
  const transactionColumns = {
    contract: [["MaHopDong", "Mã hợp đồng"], ["MaVanPhong", "Văn phòng"]],
    "daily-service": [["SoDongDaGhi", "Số dòng đã ghi"]],
    invoice: [["MaHoaDon", "Mã hóa đơn"], ["MaCongTy", "Công ty"], ["TongTien", "Tổng tiền"]],
    payment: [["MaHoaDon", "Mã hóa đơn"], ["TrangThai", "Trạng thái"], ["NgayThanhToan", "Ngày thanh toán"], ["NguoiThu", "Người thu"], ["SoTienDaThu", "Số tiền đã thu"]],
    payroll: [["MaNVTN", "Nhân viên"], ["Thang", "Tháng"], ["Nam", "Năm"], ["LuongCoBan", "Lương cơ bản"], ["TienThuong", "Thưởng"], ["TongLuong", "Tổng lương"]]
  };
  let route = location.hash.slice(1) || "dashboard";
  let editing = null;
  let recentRecordId = "";
  const reportState = {};
  const reportPages = {};
  // Ghi dữ liệu (CRUD, trang quản lý toà nhà) báo hiệu để báo cáo tải lại số liệu mới.
  window.addEventListener("office:data-changed", () => { for (const key of Object.keys(reportState)) delete reportState[key]; });
  let reportLookups;
  let sqlMode = false;
  let transactionsReady = false;
  let paymentReady = false;

  const escape = (value) => String(value ?? "").replace(/[&<>'"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[char]);
  const money = (value) => new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND", maximumFractionDigits: 2 }).format(Number(value || 0));
  const recordLabel = (record) => record?.name || record?.code || "Chưa có dữ liệu";
  const local = {
    read() { try { return JSON.parse(localStorage.getItem(storageKey)) || {}; } catch { return {}; } },
    write(data) { localStorage.setItem(storageKey, JSON.stringify(data)); },
    list(entity) { return this.read()[entity] || []; },
    save(entity, record) { const all = this.read(); const rows = all[entity] || []; const index = rows.findIndex((row) => row.id === record.id); index < 0 ? rows.push(record) : rows.splice(index, 1, record); all[entity] = rows; this.write(all); return record; },
    remove(entity, id) { const all = this.read(); all[entity] = (all[entity] || []).filter((row) => row.id !== id); this.write(all); }
  };
  const request = async (path, options = {}) => {
    const response = await fetch(`${config.apiBase}${path}`, { headers: { "Content-Type": "application/json", ...(options.headers || {}) }, ...options });
    if (!response.ok) { const body = await response.json().catch(() => ({})); const error = new Error(body.message || `Yêu cầu thất bại (${response.status})`); error.code = body.code; throw error; }
    return response.status === 204 ? null : response.json();
  };
  const modeReady = config.apiBase ? request("/health").then((health) => {
    sqlMode = health.dataMode === "sqlserver";
    transactionsReady = Boolean(health.transactionsReady);
    paymentReady = Boolean(health.paymentReady);
    const chip = document.querySelector(".integration-chip");
    const sidebarStatus = document.querySelector(".sidebar-status");
    if (chip) { chip.textContent = sqlMode ? "SQL Server" : "Chế độ cục bộ"; chip.title = sqlMode ? health.database : "Dữ liệu lưu trên máy này"; }
    if (sidebarStatus) sidebarStatus.textContent = sqlMode ? "SQL Server" : "Chế độ cục bộ";
  }).catch(() => {}) : Promise.resolve();
  const gateway = {
    async list(entity) { return config.apiBase ? request(`/${entity}`) : local.list(entity); },
    async save(entity, record) { if (!config.apiBase) return local.save(entity, record); const { id, ...fields } = record; return id ? request(`/${entity}/${id}`, { method: "PUT", body: JSON.stringify(fields) }) : request(`/${entity}`, { method: "POST", body: JSON.stringify(fields) }); },
    async remove(entity, id) { if (!config.apiBase) return local.remove(entity, id); return request(`/${entity}/${id}`, { method: "DELETE" }); }
  };
  const notify = (message, isError = false) => { const node = document.createElement("div"); node.className = `toast${isError ? " error" : ""}`; node.textContent = message; document.querySelector("#toast-region").append(node); setTimeout(() => node.classList.add("is-leaving"), 4000); setTimeout(() => node.remove(), 4300); };
  const setButtonBusy = (button, label = "Đang xử lý…") => {
    if (!button || button.disabled) return () => { };
    const originalLabel = button.textContent;
    button.disabled = true; button.setAttribute("aria-busy", "true"); button.classList.add("is-busy"); button.textContent = label;
    return () => { button.disabled = false; button.removeAttribute("aria-busy"); button.classList.remove("is-busy"); button.textContent = originalLabel; };
  };
  const explainError = (error) => error.message || "Có lỗi xảy ra. Hãy thử lại.";

  function navMarkup() {
    const general = [["dashboard", "Tổng quan"], ...Object.entries(schemas).map(([key, item]) => [key, item.title]), ["buildings", "Quản lý toà nhà"], ["transactions", "Giao dịch"]];
    const reportLinks = Object.entries(reports).map(([key, item]) => [`report-${key}`, item.title]);
    // TV6 sửa: tạm ẩn mục TV7 trên web; phần tra cứu và API vẫn được giữ để dùng khi cần demo.
    // return `<p class="nav-group">VẬN HÀNH</p>${general.map(link).join("")}<p class="nav-group">BÁO CÁO</p>${reportLinks.map(link).join("")}<p class="nav-group">CSDL PHÂN TÁN</p>${link(["tv7", "Tra cứu TV7"])}`;
    return `<p class="nav-group">VẬN HÀNH</p>${general.map(link).join("")}<p class="nav-group">BÁO CÁO</p>${reportLinks.map(link).join("")}`;
    function link([key, label]) { return `<button class="nav-item" data-route="${key}" ${route === key ? 'aria-current="page"' : ""}>${escape(label)}</button>`; }
  }
  function setHeading(heading, trail) { title.textContent = heading; breadcrumb.textContent = trail || heading.toUpperCase(); }
  function pageHeader(heading, description, action = "") { return `<section class="page-header"><div><h2>${escape(heading)}</h2><p>${escape(description)}</p></div>${action}</section>`; }
  function empty(message) { return `<p class="empty">${escape(message)}</p>`; }
  function loadingMarkup() { return `<div class="loading-skeleton" aria-live="polite" aria-label="Đang tải nội dung"><span></span><div class="grid kpis"><i></i><i></i><i></i><i></i></div><b></b></div>`; }
  function chartMarkup(points, report) {
    if (!points?.length) return `<div class="report-placeholder"><div><strong>Không có dữ liệu trong phạm vi lọc.</strong></div></div>`;
    const max = Math.max(...points.map((point) => Math.abs(Number(point.value) || 0)), 1);
    return `<div class="chart-bars" role="img" aria-label="${escape(report.title)}: ${points.map((point) => `${point.label} ${money(point.value)}`).join(", ")}">${points.map((point) => `<div class="chart-bar-item"><span class="chart-label">${escape(point.label)}</span><div class="chart-track"><span class="chart-value${Number(point.value) < 0 ? " is-negative" : ""}" style="width:${Math.max(2, Math.abs(Number(point.value) || 0) / max * 100)}%"></span></div><strong>${money(point.value)}</strong></div>`).join("")}</div>`;
  }
  function table(columns, rows, action = "", formatCell = (_, value) => value) {
    if (!rows.length) return empty("Chưa có dữ liệu. Kết nối SQL Server hoặc nhập dữ liệu qua các form quản lý.");
    return `<div class="table-wrap"><table class="data-table"><thead><tr>${columns.map(([, label]) => `<th scope="col">${escape(label)}</th>`).join("")}${action ? "<th scope=\"col\">Thao tác</th>" : ""}</tr></thead><tbody>${rows.map((row) => `<tr class="${row.id === recentRecordId ? "is-new" : ""}">${columns.map(([key]) => `<td>${escape(formatCell(key, key === "type" ? ({ company: "Công ty", building: "Tòa nhà" }[row[key]] || row[key]) : key === "status" ? ({ TRONG: "Trống", DANG_THUE: "Đang thuê" }[row[key]] || (sqlMode ? "Chưa áp dụng TV5" : "—")) : row[key]))}</td>`).join("")}${action ? `<td>${action(row)}</td>` : ""}</tr>`).join("")}</tbody></table></div>`;
  }
  async function renderDashboard() {
    const totals = await Promise.all(Object.keys(schemas).map((entity) => gateway.list(entity).then((rows) => [entity, rows.length])));
    const count = Object.fromEntries(totals);
    setHeading("Tổng quan", "TỔNG QUAN");
    // TV6 sửa: tổng quan phản ánh đúng trạng thái procedure thanh toán trên CSDL hiện tại.
    const integrationMessage = !sqlMode ? "CRUD được lưu cục bộ; giao dịch và báo cáo tài chính cần SQL Server."
      : !transactionsReady ? "Chưa đủ thủ tục và trigger trên CSDL này."
        : paymentReady ? "Đủ năm giao dịch đã sẵn sàng."
          : "Bốn giao dịch nền đã sẵn sàng; cần cài thêm thủ tục thanh toán.";
    main.innerHTML = `${pageHeader("Trung tâm vận hành", sqlMode ? "Quản lý dữ liệu công ty, toà nhà và hợp đồng." : "Quản lý dữ liệu cục bộ.")}<div class="grid kpis">${[["Công ty", count.companies], ["Văn phòng", count.offices], ["Hợp đồng", count.contracts], ["Nhân viên", count.employees]].map(([label, value]) => `<article class="card kpi"><p>${label}</p><strong>${value}</strong></article>`).join("")}</div><div class="grid split" style="margin-top:16px"><section class="card section"><h3>Trạng thái tích hợp</h3><div class="notice"><span aria-hidden="true">i</span><div><strong>${sqlMode ? "SQL Server" : "Chế độ cục bộ"}</strong><span>${escape(integrationMessage)}</span></div></div></section><section class="card section"><h3>Việc cần làm tiếp theo</h3><p class="section-note">${sqlMode ? "Quản lý danh mục, thực hiện giao dịch được hỗ trợ hoặc tra cứu báo cáo." : "Nhập thử các thực thể bằng CRUD hoặc cấu hình SQL Server để tra cứu dữ liệu."}</p></section></div>`;
  }
  async function renderTv7() {
    setHeading("Tra cứu TV7", "CSDL PHÂN TÁN");
    const state = await request("/tv7/distribution");
    const status = (value) => value === "connected" ? "Đã kết nối" : "Chưa kết nối";
    const checks = state.checks ? Object.entries(state.checks).map(([key, item]) => {
      const labels = { buildings: "Tòa nhà", offices: "Văn phòng", contracts: "Hợp đồng", invoices: "Hóa đơn", usage: "Nhật ký dịch vụ", payrollKeys: "Kỳ lương", companyProfiles: "Hồ sơ công ty", payrollAmounts: "Tiền lương", companies: "Tái thiết công ty", mongoBuildings: "MongoDB: tòa nhà", mongoOffices: "MongoDB: văn phòng", mongoContracts: "MongoDB: hợp đồng", mongoInvoices: "MongoDB: hóa đơn", mongoUsage: "MongoDB: nhật ký" };
      return `<tr><td>${escape(labels[key] || key)}</td><td>${escape(item.siteCount ?? "—")}</td><td>${escape(item.centralCount ?? "—")}</td><td>${item.status === "matched" ? "Khớp" : "Không khớp"}</td></tr>`;
    }).join("") : "";
    main.innerHTML = `${pageHeader("Tra cứu phân tán TV7", "Đọc trực tiếp ba site SQL và MongoDB; đối soát với BCNF TV3 khi các nguồn sẵn có. Không ghi dữ liệu.")}
      <section class="card section"><h3>Nguồn SQL</h3><p class="section-note">TV3 tập trung: ${escape(state.central.database)} · ${status(state.central.status)}</p>
      <div class="grid tv7-sites">${state.sites.map((site) => `<article class="tv7-site"><h4>Site ${site.id} · ${escape(site.building)}</h4><p>${escape(site.database)} · <strong>${status(site.status)}</strong></p>${site.status === "connected" ? `<p>${site.buildings.map((row) => `${escape(row.id)} · ${escape(row.name)}`).join(", ")}</p><p>Văn phòng: ${site.officeIds.map(escape).join(", ") || "0"}</p><p>Hợp đồng ${site.counts.contracts} · Hóa đơn ${site.counts.invoices} · Nhật ký ${site.counts.usage} · Kỳ lương ${site.counts.payroll}</p>${site.checks ? `<p>Đối chiếu TV3: ${Object.entries(site.checks).map(([key, check]) => `${escape(key)} ${check.status === "matched" ? "khớp" : "lệch"}`).join(" · ")}</p>` : ""}` : `<p class="section-note">Không có kết quả truy vấn từ site này.</p>`}</article>`).join("")}</div></section>
      <section class="card section tv7-block"><h3>MongoDB · ${escape(state.mongo.database)}</h3><p>${status(state.mongo.status)}</p>${state.mongo.status === "connected" ? `<p>Tòa nhà: ${state.mongo.buildings.map((row) => `${escape(row.id)} (${escape(row.officeIds.length)} văn phòng)`).join(", ") || "0"}</p><p>Hợp đồng theo tòa: ${state.mongo.contracts.map((row) => `${escape(row.buildingId)}: ${escape(row.contractIds.length)} hợp đồng, ${escape(row.invoiceIds.length)} hóa đơn`).join(", ") || "0"}</p><p>Nhật ký theo tòa: ${state.mongo.usage.map((row) => `${escape(row.buildingId)}: ${escape(row.count)}`).join(", ") || "0"}</p>` : `<p class="section-note">Không có kết quả MongoDB. Cấu hình TV7_MONGO_URI để đọc các collection thật.</p>`}</section>
      <section class="card section tv7-block"><h3>Đối soát truy vấn thực</h3>${checks ? `<div class="table-wrap"><table class="data-table"><thead><tr><th>Phân mảnh</th><th>Site / MongoDB</th><th>TV3</th><th>Kết quả</th></tr></thead><tbody>${checks}</tbody></table></div><p class="section-note">Chỉ hiện các nguồn đã kết nối và có thể đối chiếu với TV3. Mảnh công ty được so cả hồ sơ; lương được so khóa kỳ và số tiền.</p>` : `<p class="section-note">Cần kết nối đủ ba site SQL và CSDL TV3 để đối soát toàn chuỗi. Site đã kết nối được đối chiếu riêng ở phần Nguồn SQL. Không dùng JSON mẫu để tạo kết quả.</p>`}</section>`;
  }
  function fieldMarkup([key, label, type = "text", required = true], draft, lookups) {
    const value = draft[key] ?? "";
    const choices = { employeeKinds: [{ id: "company", name: "Nhân viên công ty" }, { id: "building", name: "Nhân viên tòa nhà" }],
      genders: [{ id: "M", name: "Nam" }, { id: "F", name: "Nữ" }, { id: "O", name: "Khác" }],
      employeeTypes: [{ id: "QUAN_LY", name: "Quản lý" }, { id: "DICH_VU", name: "Nhân viên dịch vụ" }], ...lookups }[type];
    if (choices && (sqlMode || choices.length || ["employeeKinds", "genders", "employeeTypes"].includes(type))) {
      const disabled = key === "type" && draft.id ? "disabled" : "";
      return `<label class="field">${escape(label)}<select name="${key}" ${required ? "required" : ""} ${disabled}><option value="">Chọn ${escape(label.toLowerCase())}</option>${choices.map((choice) => `<option value="${escape(choice.id)}" ${choice.id === value ? "selected" : ""} ${choice.buildingId ? `data-building="${escape(choice.buildingId)}"` : ""}>${escape(choice.name)} (${escape(choice.id)})</option>`).join("")}</select>${disabled ? `<input type="hidden" name="${key}" value="${escape(value)}">` : ""}</label>`;
    }
    const extra = key === "code" ? `maxlength="20" pattern="[A-Za-z0-9_-]+" ${draft.id ? "readonly" : ""}` :
      key === "taxCode" ? 'pattern="[0-9]{10}(-[0-9]{3})?" maxlength="14"' :
      key === "floor" ? 'min="1" max="32767" step="1"' :
      key === "area" || key === "basePrice" ? `min="${key === "area" || key === "basePrice" ? "0.01" : "0"}" step="0.01"` : "";
    return `<label class="field">${escape(label)}<input name="${key}" type="${type}" value="${escape(value)}" ${required ? "required" : ""} ${extra}></label>`;
  }
  function syncEmployeeFields(form) {
    const type = form.querySelector('select[name="type"]').value;
    for (const group of ["company", "building"]) {
      const section = form.querySelector(`[data-employee-group="${group}"]`);
      section.hidden = type !== group;
      for (const control of section.querySelectorAll("input, select")) {
        control.disabled = type !== group;
        control.required = type === group && !["endDate", "managerId"].includes(control.name);
      }
    }
    if (type === "building") {
      const manager = form.elements.managerId; const service = form.elements.employeeType.value === "DICH_VU";
      manager.required = service;
      manager.disabled = !service;
      if (!service) manager.value = "";
      const buildingId = form.elements.buildingId.value;
      for (const option of manager.options || []) {
        if (!option.value) continue;
        option.disabled = option.dataset.building !== buildingId || option.value === form.elements.code.value;
      }
      if (manager.selectedOptions?.[0]?.disabled) manager.value = "";
    }
  }
  async function renderCrud(entity) {
    const schema = schemas[entity];
    const [rows, lookups] = await Promise.all([gateway.list(entity), config.apiBase ? request("/lookups") : Promise.resolve({})]);
    const draft = editing?.entity === entity ? editing.record : {};
    setHeading(schema.title, "QUẢN LÝ DỮ LIỆU");
    const inputs = schema.fields.map((field) => fieldMarkup(field, draft, lookups)).join("");
    const employeeInputs = entity === "employees" ?
      `<div data-employee-group="company">${[["companyId", "Công ty", "companies"], ["jobTitle", "Chức vụ"], ["endDate", "Ngày nghỉ việc", "date", false]].map((field) => fieldMarkup(field, draft, lookups)).join("")}</div>` +
      `<div data-employee-group="building">${[["buildingId", "Tòa nhà", "buildings"], ["employeeType", "Loại nhân viên", "employeeTypes"], ["managerId", "Quản lý trực tiếp", "managers", false]].map((field) => fieldMarkup(field, draft, lookups)).join("")}</div>` : "";
    main.innerHTML = `${pageHeader(`Quản lý ${schema.title.toLowerCase()}`, "Dữ liệu theo các cột và khóa ngoại trong lược đồ BCNF.")}<section class="card section"><h3>${draft.id ? "Cập nhật bản ghi" : `Thêm ${schema.title.toLowerCase()}`}</h3><form id="crud-form" data-entity="${entity}" class="form-grid">${inputs}${employeeInputs}<div class="form-actions"><button class="button primary" type="submit">${draft.id ? "Lưu thay đổi" : "Thêm mới"}</button>${draft.id ? '<button class="button secondary" data-cancel-edit type="button">Hủy</button>' : ""}</div></form></section><section class="card section" style="margin-top:16px"><div class="toolbar"><h3>Danh sách (${rows.length})</h3></div>${table(schema.columns, rows, (row) => `<button class="text-button" data-edit="${entity}" data-id="${escape(row.id)}">Sửa</button><button class="text-button delete" data-delete="${entity}" data-id="${escape(row.id)}">Xóa</button>`)}</section>`;
    if (entity === "employees") syncEmployeeFields(main.querySelector("#crud-form"));
  }
  function transactionSelect(name, label, choices) {
    return `<label class="field">${escape(label)}<select name="${name}" required><option value="">Chọn ${escape(label.toLowerCase())}</option>${choices.map((choice) => `<option value="${escape(choice.id)}">${escape(choice.name)} (${escape(choice.id)})</option>`).join("")}</select></label>`;
  }
  function serviceRow(lookups, services) {
    return `<div class="transaction-row">${transactionSelect("employeeId", "Nhân viên công ty", lookups.companyEmployees)}${transactionSelect("serviceId", "Dịch vụ theo lượt", services)}<label class="field">Ngày sử dụng<input name="useDate" type="date" required></label><label class="field">Số lượt<input name="quantity" type="number" min="1" max="2147483647" step="1" value="1" required></label><button class="button secondary" type="button" data-batch-remove>Xóa dòng</button></div>`;
  }
  async function renderTransactions() {
    const [lookups, services] = sqlMode ? await Promise.all([request("/lookups"), request("/services")]) : [{ companies: [], buildings: [], offices: [], companyEmployees: [], serviceTypes: [] }, []];
    const activeServices = services.filter((service) => lookups.serviceTypes.some((type) => type.id === service.serviceTypeId && type.billingType === "LUOT"));
    const fields = {
      contract: `${transactionSelect("companyId", "Công ty", lookups.companies)}${transactionSelect("buildingId", "Tòa nhà", lookups.buildings)}<label class="field">Ngày bắt đầu<input name="startDate" type="date" required></label><label class="field">Ngày kết thúc (có thể để trống)<input name="endDate" type="date"></label><fieldset class="transaction-offices"><legend>Văn phòng thuê (chọn một hoặc nhiều)</legend>${lookups.offices.map((office) => `<label data-building="${escape(office.buildingId)}"><input type="checkbox" name="officeIds" value="${escape(office.id)}"> ${escape(office.name)} (${escape(office.id)})</label>`).join("")}</fieldset>`,
      "daily-service": `<div class="transaction-batch" data-batch>${serviceRow(lookups, activeServices)}</div><button class="button secondary" type="button" data-batch-add>Thêm dòng</button>`,
      invoice: `${transactionSelect("buildingId", "Tòa nhà", lookups.buildings)}<label class="field">Kỳ hóa đơn<input name="period" type="month" required></label>`,
      // TV6 sửa: số tiền lấy từ dòng hóa đơn, chỉ đọc trên form; SQL vẫn đối soát khi ghi.
      payment: `<label class="field">Hóa đơn chưa thanh toán<select name="invoiceId" required><option value="">Chọn hóa đơn</option>${(lookups.unpaidInvoices || []).map((invoice) => `<option value="${escape(invoice.id)}" data-amount="${escape(invoice.amount)}">#${escape(invoice.id)} · ${escape(invoice.name)} · ${money(invoice.amount)}</option>`).join("")}</select></label><label class="field">Số tiền thanh toán đủ<input name="amount" type="number" min="0.01" step="0.01" readonly required></label><label class="field">Ngày thanh toán<input name="paymentDate" type="date" required></label><label class="field">Người thu (có thể để trống)<input name="collector" maxlength="100"></label>`,
      payroll: `${transactionSelect("buildingId", "Tòa nhà", lookups.buildings)}<label class="field">Kỳ lương<input name="period" type="month" required></label>`
    };
    setHeading("Giao dịch", "TÍCH HỢP NGHIỆP VỤ");
    // TV6 sửa: hiển thị năm giao dịch, khóa riêng thanh toán khi còn procedure stub.
    main.innerHTML = `${pageHeader("Giao dịch TV4", "Năm giao dịch gọi procedure trên SQL Server; thanh toán chỉ hỗ trợ trả đủ một lần, không có phiếu thu độc lập.")}${!transactionsReady ? `<div class="notice"><span aria-hidden="true">i</span><div>${sqlMode ? "Cần cài table type, procedure TV4 và sáu trigger TV5 trên CSDL này." : "Giao dịch TV4 cần chế độ SQL Server."}</div></div>` : ""}<div class="transaction-list">${transactions.map(([key, label, procedure]) => `<section class="card section transaction-card"><h3>${escape(label)}</h3><p class="section-note">${escape(procedure)}</p>${key === "payment" && transactionsReady && !paymentReady ? '<div class="notice"><span aria-hidden="true">i</span><div>Procedure thanh toán còn là bản cũ; hãy cài lại file 03_Transactions.sql.</div></div>' : ""}<form data-transaction="${key}" class="form-grid transaction-form">${fields[key]}<div class="form-actions"><button class="button primary" type="submit" ${transactionsReady && (key !== "payment" || paymentReady) ? "" : "disabled"}>Thực hiện</button></div></form><div class="transaction-result" data-result="${key}" aria-live="polite"></div></section>`).join("")}</div>`;
    syncTransactionOffices();
  }
  function syncTransactionOffices() {
    const form = main.querySelector('[data-transaction="contract"]');
    if (!form) return;
    const buildingId = form.elements.buildingId.value;
    for (const option of form.querySelectorAll(".transaction-offices label")) {
      option.hidden = !buildingId || option.dataset.building !== buildingId;
      if (option.hidden) option.querySelector("input").checked = false;
    }
  }
  function transactionBody(form) {
    const name = form.dataset.transaction;
    const data = new FormData(form);
    if (name === "contract") {
      return {
        companyId: data.get("companyId"),
        buildingId: data.get("buildingId"),
        startDate: data.get("startDate"),
        endDate: data.get("endDate"),
        officeIds: data.getAll("officeIds")
      };
    }
    if (name === "daily-service") {
      return {
        items: [...form.querySelectorAll(".transaction-row")].map((row) => ({
          employeeId: row.querySelector('[name="employeeId"]').value,
          serviceId: row.querySelector('[name="serviceId"]').value,
          useDate: row.querySelector('[name="useDate"]').value,
          quantity: Number(row.querySelector('[name="quantity"]').value)
        }))
      };
    }
    if (name === "payment") {
      // TV6 sửa: số tiền do hóa đơn quyết định, người dùng không truyền MaYeuCau giả idempotency.
      return { invoiceId: Number(data.get("invoiceId")), amount: Number(data.get("amount")),
        paymentDate: data.get("paymentDate"), collector: data.get("collector") || null };
    }
    const period = data.get("period");
    return {
      buildingId: data.get("buildingId"),
      year: Number(period?.slice(0, 4)),
      month: Number(period?.slice(5, 7))
    };
  }
  async function submitTransaction(form) {
    const name = form.dataset.transaction;
    const body = transactionBody(form);
    const output = main.querySelector(`[data-result="${name}"]`);
    const restore = setButtonBusy(form.querySelector('[type="submit"]'));
    try {
      const result = await request(`/transactions/${name}`, { method: "POST", body: JSON.stringify(body) });
      output.innerHTML = `<div class="notice"><span aria-hidden="true">✓</span><div><strong>Giao dịch thành công</strong><span>Đã ghi ${result.rows.length} dòng.</span></div></div>${table(transactionColumns[name], result.rows, "", (key, value) => ["TongTien", "LuongCoBan", "TienThuong", "TongLuong", "SoTienDaThu"].includes(key) ? money(value) : value)}`;
      output.querySelectorAll(".data-table").forEach((table) => window.OfficePager?.addPager(table));
      if (name === "payment") { form.elements.invoiceId.selectedOptions[0]?.remove(); form.reset(); form.elements.amount.value = ""; }
      for (const key of Object.keys(reportState)) delete reportState[key];
      notify("Giao dịch thành công.");
    } catch (error) {
      output.innerHTML = `<div class="notice"><span aria-hidden="true">!</span><div><strong>Giao dịch không thành công${error.code ? ` · ${escape(error.code)}` : ""}</strong><span>${escape(explainError(error))}</span></div></div>`;
      notify(`${error.code ? `${error.code}: ` : ""}${explainError(error)}`, true);
    } finally { restore(); }
  }
  async function renderReport(id) {
    const report = reports[id];
    if (sqlMode && !reportState[id]) reportState[id] = await request(`/reports/${report.endpoint}`);
    const state = reportState[id] || { summary: {}, rows: [], message: "Chưa có nguồn báo cáo. Cấu hình SQL Server để tra cứu." };
    const lookups = sqlMode ? await (reportLookups ||= request("/lookups").catch((error) => { reportLookups = null; throw error; })) : {};
    const filters = report.filters.map(([key, label, type = "text"]) => {
      const value = state.filters?.[key] || "";
      if (lookups[type]) return `<label class="field">${label}<select name="${key}"><option value="">Tất cả</option>${lookups[type].map((option) => `<option value="${escape(option.id)}" ${option.id === value ? "selected" : ""}>${escape(option.name)} (${escape(option.id)})</option>`).join("")}</select></label>`;
      return `<label class="field">${label}<input name="${key}" type="${["month", "date"].includes(type) ? type : "text"}" value="${escape(value)}" /></label>`;
    }).join("");
    setHeading(report.title, "BÁO CÁO");
    const hasSummary = report.metrics.every(([, key]) => Object.hasOwn(state.summary || {}, key));
    if (!hasSummary) {
      main.innerHTML = `${pageHeader(report.title, report.description)}<form class="card filters" data-report-filter="${id}">${filters}<button class="button primary" type="submit" ${sqlMode ? "" : "disabled"}>Áp dụng</button></form><div class="notice"><span aria-hidden="true">i</span><div>${escape(state.message || "Không thể tải báo cáo.")}</div></div>`;
      return;
    }
    const metrics = report.metrics.map(([label, key, currency = true]) => `<article class="card kpi"><p>${label}</p><strong>${currency ? money(state.summary?.[key]) : new Intl.NumberFormat("vi-VN").format(Number(state.summary?.[key] || 0))}</strong></article>`).join("");
    const rows = state.rows || [];
    const pageSize = 10;
    const pageCount = Math.max(1, Math.ceil(rows.length / pageSize));
    const page = Math.min(reportPages[id] || 0, pageCount - 1);
    const pageRows = rows.slice(page * pageSize, (page + 1) * pageSize);
    const currencyKeys = new Set(["amount", "unitPrice", "baseSalary", "bonus"]);
    const detail = pageRows.length ? table(report.columns, pageRows, "", (key, value) => currencyKeys.has(key) ? money(value) : value)
      : empty("Không có dữ liệu trong phạm vi lọc.");
    const rowAmount = rows.reduce((sum, row) => sum + Math.round(Number(row.amount || 0) * 100), 0) / 100;
    const expected = id === "payroll" ? state.summary?.totalPayroll : state.summary?.totalCost;
    const reconciled = expected === undefined || Math.round(Number(expected) * 100) === Math.round(rowAmount * 100);
    const reconcileNote = id === "payroll"
      ? `Tổng ${rows.length} dòng lương: ${money(rowAmount)}; ${reconciled ? "khớp" : "không khớp"} quỹ lương. Doanh thu dịch vụ lấy riêng từ chi tiết hóa đơn, không cộng vào lương.`
      : id === "building-cashflow" ? `Tổng các dòng: ${money(rowAmount)}; ${Math.round(rowAmount * 100) === Math.round(Number(state.summary?.netCashflow || 0) * 100) ? "khớp" : "không khớp"} chênh lệch. Khoản thu chỉ gồm hóa đơn đã thanh toán; khoản chi ghi theo đầu tháng kế toán.`
        : `Tổng ${rows.length} dòng chi tiết: ${money(rowAmount)}; ${reconciled ? "khớp" : "không khớp"} chỉ tiêu tổng tiền.`;
    const pagination = rows.length > pageSize ? `<div class="report-pagination"><span>Hiển thị ${page * pageSize + 1}–${Math.min((page + 1) * pageSize, rows.length)} / ${rows.length} dòng. CSV gồm toàn bộ dữ liệu đã lọc.</span><button class="button secondary" type="button" data-report-page="${id}" data-direction="-1" ${page === 0 ? "disabled" : ""}>Trước</button><button class="button secondary" type="button" data-report-page="${id}" data-direction="1" ${page === pageCount - 1 ? "disabled" : ""}>Sau</button></div>` : "";
    main.innerHTML = `${pageHeader(report.title, report.description, `<button class="button secondary" data-export="${id}" ${rows.length ? "" : "disabled"}>Xuất CSV</button>`)}<form class="card filters" data-report-filter="${id}">${filters}<button class="button primary" type="submit">Áp dụng</button></form>${state.message ? `<div class="notice"><span aria-hidden="true">i</span><div>${escape(state.message)}</div></div>` : ""}<div class="grid kpis">${metrics}</div><div class="grid split" style="margin-top:16px"><section class="card section"><h3>Xu hướng / so sánh</h3>${chartMarkup(state.chart, report)}</section><section class="card section"><h3>Ghi chú đối soát</h3><p class="section-note">${escape(reconcileNote)}</p></section></div><section class="card section" style="margin-top:16px"><h3>Dữ liệu chi tiết (${rows.length})</h3>${detail}${pagination}</section>`;
  }
  async function render() {
    nav.innerHTML = navMarkup(); main.innerHTML = loadingMarkup(); main.classList.remove("is-entering");
    try {
      await modeReady;
      if (route === "dashboard") await renderDashboard();
      else if (schemas[route]) await renderCrud(route);
      else if (route === "transactions") await renderTransactions();
      else if (route === "buildings") await window.renderBuildingManage({ main, pageHeader, setHeading, escape, money, notify, request, sqlMode });
      // TV6 sửa: tạm ẩn route TV7; URL #tv7 sẽ quay về trang Tổng quan.
      // else if (route === "tv7") await renderTv7();
      else if (route.startsWith("report-")) await renderReport(route.replace("report-", ""));
      else { route = "dashboard"; location.hash = route; }
    }
    catch (error) { main.innerHTML = `<div class="notice"><div><strong>Không thể tải dữ liệu</strong><span>${escape(explainError(error))}</span></div></div>`; }
    requestAnimationFrame(() => main.classList.add("is-entering"));
  }
  async function submitCrud(form) {
    const entity = form.dataset.entity; const record = Object.fromEntries(new FormData(form).entries());
    if (editing?.entity === entity) record.id = editing.record.id;
    const restore = setButtonBusy(form.querySelector('[type="submit"]'));
    try { const saved = await gateway.save(entity, record); reportLookups = null; window.dispatchEvent(new Event("office:data-changed")); recentRecordId = saved?.id || record.id; editing = null; notify("Đã lưu dữ liệu."); await render(); setTimeout(() => { recentRecordId = ""; }, 900); } catch (error) { restore(); notify(explainError(error), true); }
  }
  async function loadReport(id, form) {
    if (!config.apiBase) { reportState[id] = { summary: {}, rows: [], message: "Chưa cấu hình API/SQL Server nên không có số liệu tài chính để hiển thị." }; return render(); }
    const query = new URLSearchParams(new FormData(form));
    const restore = setButtonBusy(form.querySelector('[type="submit"]'), "Đang tải…");
    try { const result = await request(`/reports/${reports[id].endpoint}?${query}`); reportState[id] = { ...result, filters: Object.fromEntries(query), message: result.message || "" }; reportPages[id] = 0; await render(); } catch (error) { restore(); reportState[id] = { summary: {}, rows: [], filters: Object.fromEntries(query), message: explainError(error) }; reportPages[id] = 0; await render(); }
  }
  function exportCsv(id) {
    const report = reports[id]; const rows = reportState[id]?.rows || []; const values = [report.columns.map(([, label]) => label), ...rows.map((row) => report.columns.map(([key]) => row[key] ?? ""))];
    const csv = values.map((row) => row.map((value) => `"${String(value).replaceAll('"', '""')}"`).join(",")).join("\n"); const url = URL.createObjectURL(new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8" })); const link = document.createElement("a"); link.href = url; link.download = `${id}.csv`; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); notify("Đã xuất CSV.");
  }
  document.addEventListener("click", async (event) => {
    const target = event.target.closest("button"); if (!target) return;
    if (target.dataset.route) { route = target.dataset.route; location.hash = route; return; }
    if (target.id === "menu-toggle") { const sidebar = document.querySelector(".sidebar"); sidebar.classList.toggle("open"); target.setAttribute("aria-expanded", String(sidebar.classList.contains("open"))); return; }
    if (target.dataset.cancelEdit !== undefined) { editing = null; return render(); }
    if (target.dataset.edit) { const rows = await gateway.list(target.dataset.edit); editing = { entity: target.dataset.edit, record: rows.find((row) => row.id === target.dataset.id) }; return render(); }
    if (target.dataset.delete) { if (!confirm("Bạn có chắc muốn xóa bản ghi này?")) return; const restore = setButtonBusy(target, "Đang xóa…"); try { await gateway.remove(target.dataset.delete, target.dataset.id); reportLookups = null; window.dispatchEvent(new Event("office:data-changed")); notify("Đã xóa bản ghi."); await render(); } catch (error) { restore(); notify(explainError(error), true); } }
    if (target.dataset.export) exportCsv(target.dataset.export);
    if (target.dataset.reportPage) { reportPages[target.dataset.reportPage] = Math.max(0, (reportPages[target.dataset.reportPage] || 0) + Number(target.dataset.direction)); await render(); }
    if (target.dataset.batchAdd !== undefined) { const rows = target.previousElementSibling; if (rows.children.length < 200) rows.insertAdjacentHTML("beforeend", rows.firstElementChild.outerHTML); return; }
    if (target.dataset.batchRemove !== undefined) { const rows = target.closest("[data-batch]"); if (rows.children.length > 1) target.closest(".transaction-row").remove(); return; }
  });
  document.addEventListener("submit", (event) => { if (event.target.id === "crud-form") { event.preventDefault(); submitCrud(event.target); } if (event.target.dataset.reportFilter) { event.preventDefault(); loadReport(event.target.dataset.reportFilter, event.target); } if (event.target.dataset.transaction) { event.preventDefault(); submitTransaction(event.target); } });
  document.addEventListener("change", (event) => { const form = event.target.closest("#crud-form"); if (form?.dataset.entity === "employees") syncEmployeeFields(form); if (event.target.closest('[data-transaction="contract"]') && event.target.name === "buildingId") syncTransactionOffices();
    // TV6 sửa: đồng bộ số tiền chỉ đọc khi chọn hóa đơn chưa thanh toán.
    if (event.target.closest('[data-transaction="payment"]') && event.target.name === "invoiceId") event.target.form.elements.amount.value = event.target.selectedOptions[0]?.dataset.amount || "";
  });
  window.addEventListener("hashchange", () => { route = location.hash.slice(1) || "dashboard"; editing = null; render(); });
  render();
})();
