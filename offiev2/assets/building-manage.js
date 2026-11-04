// Trang "Quản lý toà nhà" gồm ba tab: thông tin toà, nhân sự theo toà, giá dịch vụ và tham số dùng chung.
// File mới. app.js gọi window.renderBuildingManage(ctx) khi mở #buildings.
(() => {
  "use strict";

  const tabs = [["info", "Thông tin toà nhà"], ["staff", "Nhân sự"], ["prices", "Giá và tham số"]];
  const employeeTypes = { QUAN_LY: "Quản lý", DICH_VU: "Nhân viên dịch vụ" };
  const state = { ctx: null, tab: "info", buildingId: "", editing: null, adding: false, data: null };

  const buildingName = (id) => state.data.buildings.find((row) => row.id === id)?.name || id;

  function tableOf(columns, rows, rowMarkup) {
    if (!rows.length) return `<p class="empty">Chưa có dữ liệu.</p>`;
    const { escape } = state.ctx;
    return `<div class="table-wrap"><table class="data-table"><thead><tr>${columns.map((label) => `<th scope="col">${escape(label)}</th>`).join("")}</tr></thead><tbody>${rows.map(rowMarkup).join("")}</tbody></table></div>`;
  }

  function buildingSelect() {
    const { escape } = state.ctx;
    return `<label class="field">Toà nhà<select data-bm-select="buildingId">${state.data.buildings.map((row) => `<option value="${escape(row.id)}" ${row.id === state.buildingId ? "selected" : ""}>${escape(row.name)}</option>`).join("")}</select></label>`;
  }

  function infoBody() {
    const { escape } = state.ctx;
    const editingRow = state.data.buildings.find((row) => row.id === state.editing);
    const form = editingRow ? `<form class="card filters" data-bm-form="building" data-id="${escape(editingRow.id)}">
      <label class="field">Tên toà nhà<input name="name" required value="${escape(editingRow.name)}"></label>
      <label class="field">Địa chỉ<input name="address" required value="${escape(editingRow.address)}"></label>
      <label class="field">Số tầng<input name="floors" type="number" min="1" step="1" required value="${escape(editingRow.floors)}"></label>
      <div class="form-actions"><button class="button primary" type="submit">Lưu thay đổi</button><button class="button secondary" type="button" data-bm-cancel>Hủy</button></div>
    </form>` : "";
    const table = tableOf(["Mã", "Tên toà nhà", "Địa chỉ", "Số tầng", "Thao tác"], state.data.buildings, (row) =>
      `<tr><td>${escape(row.id)}</td><td>${escape(row.name)}</td><td>${escape(row.address)}</td><td>${escape(row.floors)}</td>` +
      `<td><button class="text-button" type="button" data-bm-edit="${escape(row.id)}">Sửa</button></td></tr>`);
    const addForm = state.adding ? `<form class="card filters" data-bm-form="building-new">
      <label class="field">Tên toà nhà<input name="name" required></label>
      <label class="field">Địa chỉ<input name="address" required></label>
      <label class="field">Số tầng<input name="floors" type="number" min="1" step="1" required></label>
      <div class="form-actions"><button class="button primary" type="submit">Tạo toà nhà</button><button class="button secondary" type="button" data-bm-cancel>Hủy</button></div>
    </form>` : `<div class="form-actions"><button class="button primary" type="button" data-bm-add>Thêm toà nhà</button></div>`;
    return `${addForm}${form}<section class="card section"><h3>Danh sách toà nhà</h3>${table}</section>`;
  }

  function staffBody() {
    const { escape } = state.ctx;
    const staff = state.data.staff.filter((row) => row.buildingId === state.buildingId);
    const managers = staff.filter((row) => row.employeeType === "QUAN_LY").length;
    const services = staff.length - managers;
    const table = tableOf(["Mã", "Họ tên", "Loại", "Quản lý trực tiếp"], staff, (row) =>
      `<tr><td>${escape(row.id)}</td><td>${escape(row.name)}</td><td>${escape(employeeTypes[row.employeeType] || row.employeeType)}</td><td>${escape(row.managerName || "—")}</td></tr>`);
    return `<section class="card section"><div class="form-actions">${buildingSelect()}</div>
      <p class="section-note">${escape(buildingName(state.buildingId))}: ${managers} quản lý, ${services} nhân viên dịch vụ.</p>${table}</section>`;
  }

  function pricesBody() {
    const { escape, money } = state.ctx;
    const services = state.data.services.filter((row) => row.buildingId === state.buildingId);
    const serviceTable = tableOf(["Mã", "Dịch vụ", "Loại", "Đơn giá hiện tại", "Đơn giá mới", ""], services, (row) =>
      `<tr><td>${escape(row.id)}</td><td>${escape(row.name)}</td><td>${escape(row.serviceType)}</td><td>${money(row.basePrice)}</td>` +
      `<td><input type="number" min="1" step="1000" data-bm-input="service:${escape(row.id)}" value="${escape(row.basePrice)}"></td>` +
      `<td><button class="text-button" type="button" data-bm-save="service" data-id="${escape(row.id)}">Lưu</button></td></tr>`);
    const paramTable = tableOf(["Tham số", "Giá trị", "Ý nghĩa", ""], state.data.parameters, (row) =>
      `<tr><td>${escape(row.name)}</td><td><input type="number" min="0" step="any" data-bm-input="param:${escape(row.name)}" value="${escape(row.value)}"></td>` +
      `<td>${escape(row.description)}</td><td><button class="text-button" type="button" data-bm-save="param" data-id="${escape(row.name)}">Lưu</button></td></tr>`);
    const locationTable = tableOf(["Mã", "Vị trí", "Đơn giá thuê m²", ""], state.data.locations, (row) =>
      `<tr><td>${escape(row.id)}</td><td>${escape(row.name)}</td><td><input type="number" min="1" step="1000" data-bm-input="location:${escape(row.id)}" value="${escape(row.pricePerM2)}"></td>` +
      `<td><button class="text-button" type="button" data-bm-save="location" data-id="${escape(row.id)}">Lưu</button></td></tr>`);
    return `<section class="card section"><h3>Đơn giá dịch vụ của toà</h3><div class="form-actions">${buildingSelect()}</div>${serviceTable}</section>
      <section class="card section"><h3>Tham số tính toán dùng chung</h3><p class="section-note">Áp dụng cho toàn hệ thống, không theo từng toà.</p>${paramTable}</section>
      <section class="card section"><h3>Đơn giá thuê m² theo vị trí</h3><p class="section-note">Dùng chung toàn hệ thống, không theo từng toà.</p>${locationTable}</section>`;
  }

  function draw() {
    const { main, pageHeader, escape } = state.ctx;
    const body = { info: infoBody, staff: staffBody, prices: pricesBody }[state.tab]();
    main.innerHTML = `${pageHeader("Quản lý toà nhà", "Thông tin toà, nhân sự theo toà, giá dịch vụ và tham số dùng chung.")}
      <div class="form-actions" role="tablist">${tabs.map(([key, label]) => `<button class="button ${state.tab === key ? "primary" : "secondary"}" type="button" role="tab" aria-selected="${state.tab === key}" data-bm-tab="${key}">${escape(label)}</button>`).join("")}</div>
      <div id="bm-body">${body}</div>`;
    // Phân trang cho mọi bảng trên trang (bộ phân trang dùng chung từ search-enhance.js).
    if (window.OfficePager) main.querySelectorAll("#bm-body .data-table").forEach((table) => window.OfficePager.addPager(table));
  }

  async function reload(message) {
    window.dispatchEvent(new Event("office:data-changed"));
    state.data = await state.ctx.request("/buildings/manage");
    state.ctx.notify(message);
    draw();
  }

  async function save(kind, id, main) {
    const { request, notify } = state.ctx;
    const value = main.querySelector(`[data-bm-input="${kind}:${CSS.escape(id)}"]`)?.value;
    try {
      if (kind === "service") await request(`/buildings/services/${id}/price`, { method: "PUT", body: JSON.stringify({ basePrice: Number(value) }) });
      if (kind === "param") await request(`/buildings/parameters/${encodeURIComponent(id)}`, { method: "PUT", body: JSON.stringify({ value: Number(value) }) });
      if (kind === "location") await request(`/buildings/locations/${id}/price`, { method: "PUT", body: JSON.stringify({ pricePerM2: Number(value) }) });
      await reload("Đã lưu giá.");
    } catch (error) { notify(error.message, true); }
  }

  window.renderBuildingManage = async function (ctx) {
    state.ctx = ctx;
    const { main, pageHeader, setHeading, sqlMode } = ctx;
    setHeading("Quản lý toà nhà", "VẬN HÀNH");
    if (!sqlMode) {
      main.innerHTML = `${pageHeader("Quản lý toà nhà", "Trang này cần MySQL.")}<div class="notice"><span aria-hidden="true">i</span><div><strong>Chưa kết nối MySQL</strong><span>Cấu hình MySQL để xem và sửa thông tin toà nhà.</span></div></div>`;
      return;
    }
    state.data = await ctx.request("/buildings/manage");
    if (!state.data.buildings.some((row) => row.id === state.buildingId)) state.buildingId = state.data.buildings[0]?.id || "";
    draw();

    main.onclick = async (event) => {
      const tab = event.target.closest("[data-bm-tab]");
      if (tab) { state.tab = tab.dataset.bmTab; state.editing = null; draw(); return; }
      const edit = event.target.closest("[data-bm-edit]");
      if (edit) { state.editing = edit.dataset.bmEdit; draw(); return; }
      if (event.target.closest("[data-bm-add]")) { state.adding = true; state.editing = null; draw(); return; }
      if (event.target.closest("[data-bm-cancel]")) { state.editing = null; state.adding = false; draw(); return; }
      const saveButton = event.target.closest("[data-bm-save]");
      if (saveButton) await save(saveButton.dataset.bmSave, saveButton.dataset.id, main);
    };
    main.onchange = (event) => {
      if (event.target.dataset.bmSelect === "buildingId") { state.buildingId = event.target.value; draw(); }
    };
    main.onsubmit = async (event) => {
      const { request, notify } = state.ctx;
      const created = event.target.closest("[data-bm-form='building-new']");
      if (created) {
        event.preventDefault();
        try {
          await request("/buildings", { method: "POST", body: JSON.stringify(Object.fromEntries(new FormData(created).entries())) });
          state.adding = false;
          await reload("Đã tạo toà nhà mới.");
        } catch (error) { notify(error.message, true); }
        return;
      }
      const form = event.target.closest("[data-bm-form='building']");
      if (!form) return;
      event.preventDefault();
      try {
        await request(`/buildings/${form.dataset.id}`, { method: "PUT", body: JSON.stringify(Object.fromEntries(new FormData(form).entries())) });
        state.editing = null;
        await reload("Đã lưu thông tin toà nhà.");
      } catch (error) { notify(error.message, true); }
    };
  };
})();
