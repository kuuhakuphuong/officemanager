// Tìm kiếm, lọc và xuất file cho các trang vận hành. File mới, không sửa app.js:
// quan sát khu vực nội dung, khi bảng danh sách xuất hiện thì thêm ô tìm kiếm phía trên
// và nút "Xuất file" cho từng hợp đồng/nhân viên (cùng hàng với Sửa, Xóa).
// Tìm kiếm gọi GET /api/search/:mục; các dòng không khớp được ẩn.
(function () {
  const routes = ["companies", "offices", "contracts", "services", "employees"];
  const exportable = ["contracts", "employees"];
  const fields = {
    companies: [["q", "Tìm theo tên, mã số thuế, mã"], ["sector", "Lĩnh vực", "sectors"]],
    offices: [["q", "Tìm theo mã văn phòng"], ["buildingId", "Tòa nhà", "buildings"], ["locationId", "Vị trí", "locations"], ["status", "Trạng thái", "statuses"]],
    contracts: [["q", "Tìm theo mã HĐ, công ty, văn phòng"], ["companyId", "Công ty", "companies"], ["officeId", "Văn phòng", "offices"], ["active", "Hiệu lực", "activeStates"]],
    services: [["q", "Tìm theo mã, tên dịch vụ"], ["buildingId", "Tòa nhà", "buildings"], ["serviceTypeId", "Loại dịch vụ", "serviceTypes"]],
    employees: [["q", "Tìm theo mã, họ tên, email"], ["type", "Thuộc", "employeeKinds"], ["companyId", "Công ty", "companies"], ["buildingId", "Tòa nhà", "buildings"]]
  };
  const staticOptions = {
    statuses: [["TRONG", "Trống"], ["DANG_THUE", "Đang thuê"]],
    activeStates: [["1", "Đang hiệu lực"], ["0", "Đã kết thúc"]],
    employeeKinds: [["company", "Công ty"], ["building", "Tòa nhà"]]
  };
  let lookups = null;

  const esc = (value) => String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const route = () => location.hash.replace("#", "");

  async function loadLookups() {
    if (!lookups) lookups = await fetch("/api/lookups").then((r) => r.json()).catch(() => ({}));
    return lookups;
  }

  function optionsOf(source, list, rows) {
    if (staticOptions[source]) return staticOptions[source];
    if (source === "sectors") return [...new Set(rows.map((r) => r.sector).filter(Boolean))].sort().map((v) => [v, v]);
    return (list[source] || []).map((c) => [c.id, c.name]);
  }

  function toast(message) {
    const region = document.getElementById("toast-region");
    if (!region) return;
    const item = document.createElement("div");
    item.className = "toast";
    item.textContent = message;
    region.appendChild(item);
    setTimeout(() => item.remove(), 2500);
  }

  // Xuất hồ sơ hợp đồng/nhân viên ra file Word (.doc), mở và in được.
  function exportRecordDoc(entity, record) {
    const value = (v) => esc(v === null || v === undefined || v === "" ? "—" : String(v));
    const isContract = entity === "contracts";
    const title = isContract ? "HỢP ĐỒNG THUÊ VĂN PHÒNG" : "HỒ SƠ NHÂN VIÊN";
    const pairs = isContract
      ? [["Mã hợp đồng", record.code], ["Công ty", record.company], ["Mã công ty", record.companyId], ["Văn phòng", record.officeId], ["Ngày bắt đầu", record.startDate], ["Ngày kết thúc", record.endDate || "Không xác định"]]
      : [["Mã nhân viên", record.code], ["Họ và tên", record.name], ["Thuộc", record.type === "company" ? "Công ty" : "Tòa nhà"], ["Công ty", record.company], ["Tòa nhà", record.building], ["Loại nhân viên", record.employeeType], ["Chức vụ", record.jobTitle], ["Giới tính", record.gender], ["Ngày sinh", record.birthDate], ["Điện thoại", record.phone], ["Email", record.email], ["Ngày vào làm", record.startDate], ["Ngày nghỉ việc", record.endDate]];
    const rows = pairs.map(([label, data]) => `<tr><th style="text-align:left;width:35%">${esc(label)}</th><td>${value(data)}</td></tr>`).join("");
    const html = `<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40"><head><meta charset="utf-8"><title>${title}</title></head><body style="font-family:'Times New Roman';font-size:13pt"><h2 style="text-align:center">${title}</h2><p style="text-align:center">Mã: ${value(record.code)}</p><table border="1" cellspacing="0" cellpadding="6" style="border-collapse:collapse;width:100%">${rows}</table><p>Ngày xuất: ${new Date().toLocaleDateString("vi-VN")}</p></body></html>`;
    const url = URL.createObjectURL(new Blob(["﻿" + html], { type: "application/msword" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = `${isContract ? "hop-dong" : "nhan-vien"}-${record.code}.doc`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    toast("Đã xuất file.");
  }

  // Lọc đánh dấu dòng không khớp (data-miss); phân trang chỉ hiện các dòng khớp trong trang hiện tại.
  function applyRowFilter(table, ids) {
    table.querySelectorAll("tbody tr").forEach((tr) => {
      const key = tr.querySelector("button[data-id]");
      tr.dataset.miss = !ids || (key && ids.has(key.dataset.id)) ? "" : "1";
    });
    table.dataset.page = "1";
    return paginate(table);
  }

  function paginate(table) {
    const size = Number(table.dataset.pageSize) || 10;
    const matched = [...table.querySelectorAll("tbody tr")].filter((tr) => !tr.dataset.miss);
    const pages = Math.max(1, Math.ceil(matched.length / size));
    const page = Math.min(Math.max(Number(table.dataset.page) || 1, 1), pages);
    table.dataset.page = String(page);
    table.querySelectorAll("tbody tr").forEach((tr) => { tr.hidden = true; });
    matched.slice((page - 1) * size, page * size).forEach((tr) => { tr.hidden = false; });
    const pager = table.parentElement.nextElementSibling;
    if (pager?.classList.contains("enh-pager")) {
      pager.querySelector("[data-enh-info]").textContent = `Trang ${page} / ${pages} · ${matched.length} dòng`;
      pager.querySelector("[data-enh-size]").value = String(size);
      pager.querySelector("[data-enh-prev]").disabled = page <= 1;
      pager.querySelector("[data-enh-next]").disabled = page >= pages;
    }
    return matched.length;
  }

  function addPager(table) {
    const pager = document.createElement("div");
    pager.className = "enh-pager";
    pager.style.cssText = "display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-top:12px";
    pager.innerHTML = `<label>Số dòng mỗi trang <select data-enh-size>${[10, 25, 50].map((n) => `<option value="${n}">${n}</option>`).join("")}</select></label><span data-enh-info></span><button class="button secondary" type="button" data-enh-prev>Trang trước</button><button class="button secondary" type="button" data-enh-next>Trang sau</button>`;
    table.parentElement.insertAdjacentElement("afterend", pager);
    table.dataset.pageSize = "10";
    table.dataset.page = "1";
    pager.querySelector("[data-enh-size]").addEventListener("change", (event) => {
      table.dataset.pageSize = event.target.value;
      table.dataset.page = "1";
      paginate(table);
    });
    pager.querySelector("[data-enh-prev]").addEventListener("click", () => {
      table.dataset.page = String(Number(table.dataset.page) - 1);
      paginate(table);
    });
    pager.querySelector("[data-enh-next]").addEventListener("click", () => {
      table.dataset.page = String(Number(table.dataset.page) + 1);
      paginate(table);
    });
    paginate(table);
  }

  async function enhance(main) {
    const current = route();
    if (!routes.includes(current)) return;
    const table = main.querySelector(".data-table");
    if (!table || !main.querySelector("#crud-form") || table.dataset.enhanced === current) return;
    table.dataset.enhanced = current;

    const list = await loadLookups();
    const rows = [...table.querySelectorAll("tbody tr button[data-id]")].map((b) => b.dataset.id);
    const section = table.closest("section.card.section");
    if (!section) return;

    const form = document.createElement("form");
    form.className = "card filters enh-search";
    form.setAttribute("aria-label", "Tìm kiếm và lọc");
    const controls = fields[current].map(([name, label, source]) => source
      ? `<label class="field">${esc(label)}<select name="${name}"><option value="">Tất cả</option>${optionsOf(source, list, []).map(([v, t]) => `<option value="${esc(v)}">${esc(t)}</option>`).join("")}</select></label>`
      : `<label class="field">${esc(label)}<input name="${name}" placeholder="${esc(label)}"></label>`).join("");
    form.innerHTML = `${controls}<div class="form-actions"><button class="button primary" type="submit">Tìm / lọc</button><button class="button secondary" type="button" data-enh-reset>Xóa lọc</button></div>`;
    section.parentElement.insertBefore(form, section);
    addPager(table);

    if (exportable.includes(current)) {
      table.querySelectorAll("tbody tr").forEach((tr) => {
        const button = tr.querySelector("button[data-id]");
        if (!button) return;
        const exportButton = document.createElement("button");
        exportButton.type = "button";
        exportButton.className = "text-button";
        exportButton.dataset.enhExport = current;
        exportButton.dataset.id = button.dataset.id;
        exportButton.textContent = "Xuất file";
        button.parentElement.insertBefore(exportButton, button);
      });
    }

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const params = new URLSearchParams([...new FormData(form).entries()].filter(([, v]) => v !== ""));
      const matched = await fetch(`/api/search/${current}?${params}`).then((r) => r.json());
      const shown = applyRowFilter(table, new Set(matched.map((m) => m.id)));
      toast(`Tìm thấy ${shown} dòng.`);
    });
    form.querySelector("[data-enh-reset]").addEventListener("click", () => {
      form.reset();
      applyRowFilter(table, null);
    });
    void rows;
  }

  document.addEventListener("click", async (event) => {
    const button = event.target.closest("[data-enh-export]");
    if (!button) return;
    const entity = button.dataset.enhExport;
    const records = await fetch(`/api/${entity}`).then((r) => r.json());
    const record = records.find((row) => row.id === button.dataset.id);
    if (record) exportRecordDoc(entity, record);
  });

  // Cho trang khác (quản lý toà nhà) dùng chung bộ phân trang.
  window.OfficePager = { addPager };

  const main = document.getElementById("main-content");
  if (main) {
    new MutationObserver(() => enhance(main)).observe(main, { childList: true, subtree: true });
    window.addEventListener("hashchange", () => enhance(main));
  }
})();
