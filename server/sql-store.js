const sql = require("mssql");

class ValidationError extends Error {}

const dateText = (value) => value instanceof Date ? value.toISOString().slice(0, 10) : String(value || "").slice(0, 10);
const periodText = (year, month) => `${year}-${String(month).padStart(2, "0")}`;
const amount = (value) => Number(value || 0);
const moneySum = (rows, select = (row) => row.amount) =>
  rows.reduce((cents, row) => cents + Math.round(amount(select(row)) * 100), 0) / 100;

function sqlConfig(environment = process.env) {
  const required = ["DB_SERVER", "DB_DATABASE", "DB_USER", "DB_PASSWORD"];
  const missing = required.filter((name) => !environment[name]);
  if (missing.length) throw new Error(`Missing SQL Server configuration: ${missing.join(", ")}`);
  const port = Number(environment.DB_PORT || 1433);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error("DB_PORT must be a valid TCP port");
  return {
    server: environment.DB_SERVER,
    port,
    database: environment.DB_DATABASE,
    user: environment.DB_USER,
    password: environment.DB_PASSWORD,
    options: {
      encrypt: environment.DB_ENCRYPT === "true",
      trustServerCertificate: environment.DB_TRUST_SERVER_CERTIFICATE === "true"
    }
  };
}

const listQueries = {
  companies: `SELECT MaCongTy AS id, MaCongTy AS code, TenCongTy AS name,
      MaSoThue AS taxCode, DiaChi AS address, DienThoai AS phone, Email AS email, LinhVuc AS sector
    FROM dbo.CongTy ORDER BY MaCongTy`,
  offices: `SELECT vp.MaVanPhong AS id, vp.MaVanPhong AS code, vp.MaToaNha AS buildingId,
      tn.TenToaNha AS building, vp.MaViTri AS locationId, vt.TenViTri AS location,
      vp.Tang AS floor, vp.DienTich AS area, OFFICE_STATUS AS status
    FROM dbo.VanPhong AS vp JOIN dbo.ToaNha AS tn ON tn.MaToaNha = vp.MaToaNha
    JOIN dbo.ViTri AS vt ON vt.MaViTri = vp.MaViTri
    ORDER BY vp.MaVanPhong`,
  contracts: `SELECT hd.MaHopDong AS id, hd.MaHopDong AS code, hd.MaCongTy AS companyId,
      ct.TenCongTy AS company, hd.MaVanPhong AS officeId,
      CONVERT(char(10), hd.NgayBatDau, 23) AS startDate,
      CONVERT(char(10), hd.NgayKetThuc, 23) AS endDate
    FROM dbo.HopDongThue AS hd JOIN dbo.CongTy AS ct ON ct.MaCongTy = hd.MaCongTy
    ORDER BY hd.MaHopDong`,
  services: `SELECT dv.MaDichVu AS id, dv.MaDichVu AS code, dv.MaToaNha AS buildingId,
      tn.TenToaNha AS building, dv.MaLoaiDV AS serviceTypeId, ldv.TenLoai AS serviceType,
      dv.TenDichVu AS name, dv.DonGiaCoBan AS basePrice
    FROM dbo.DichVu AS dv JOIN dbo.LoaiDichVu AS ldv ON ldv.MaLoaiDV = dv.MaLoaiDV
    JOIN dbo.ToaNha AS tn ON tn.MaToaNha = dv.MaToaNha
    ORDER BY dv.MaDichVu`,
  employees: `SELECT CONCAT('TN:', nv.MaNVTN) AS id, N'building' AS type,
      nv.MaNVTN AS code, nv.HoTen AS name, nv.GioiTinh AS gender,
      CONVERT(char(10), nv.NgaySinh, 23) AS birthDate, nv.DienThoai AS phone,
      nv.Email AS email, CONVERT(char(10), nv.NgayVaoLam, 23) AS startDate,
      CAST(NULL AS char(10)) AS endDate, CAST(NULL AS varchar(20)) AS companyId,
      CAST(NULL AS nvarchar(200)) AS company, nv.MaToaNha AS buildingId,
      tn.TenToaNha AS building, nv.MaQuanLy AS managerId, nv.LoaiNV AS employeeType,
      CAST(NULL AS nvarchar(100)) AS jobTitle
    FROM dbo.NhanVienToaNha AS nv JOIN dbo.ToaNha AS tn ON tn.MaToaNha = nv.MaToaNha
    UNION ALL
    SELECT CONCAT('CT:', nv.MaNVCT), N'company', nv.MaNVCT, nv.HoTen, nv.GioiTinh,
      CONVERT(char(10), nv.NgaySinh, 23), nv.DienThoai, nv.Email,
      CONVERT(char(10), nv.NgayVaoLam, 23), CONVERT(char(10), nv.NgayNghiViec, 23),
      nv.MaCongTy, ct.TenCongTy, CAST(NULL AS varchar(20)), CAST(NULL AS nvarchar(150)),
      CAST(NULL AS varchar(20)), CAST(NULL AS varchar(10)), nv.ChucVu
    FROM dbo.NhanVienCongTy AS nv JOIN dbo.CongTy AS ct ON ct.MaCongTy = nv.MaCongTy
    ORDER BY type, code`
};

const lookupQueries = {
  buildings: `SELECT MaToaNha AS id, TenToaNha AS name, SoTang AS floors FROM dbo.ToaNha ORDER BY TenToaNha`,
  locations: `SELECT MaViTri AS id, TenViTri AS name FROM dbo.ViTri ORDER BY TenViTri`,
  serviceTypes: `SELECT MaLoaiDV AS id, TenLoai AS name, KieuTinhPhi AS billingType FROM dbo.LoaiDichVu ORDER BY TenLoai`,
  companies: `SELECT MaCongTy AS id, TenCongTy AS name FROM dbo.CongTy ORDER BY TenCongTy`,
  companyEmployees: `SELECT MaNVCT AS id, HoTen AS name, MaCongTy AS companyId
    FROM dbo.NhanVienCongTy ORDER BY HoTen, MaNVCT`,
  offices: `SELECT MaVanPhong AS id, MaVanPhong AS name, MaToaNha AS buildingId FROM dbo.VanPhong ORDER BY MaVanPhong`,
  managers: `SELECT MaNVTN AS id, HoTen AS name, MaToaNha AS buildingId FROM dbo.NhanVienToaNha WHERE LoaiNV = 'QUAN_LY' ORDER BY HoTen`,
  // TV6 sửa: thanh toán chỉ chọn hóa đơn chưa trả và dùng đúng tổng tiền từ view TV3.
  unpaidInvoices: `SELECT hd.MaHoaDon AS id,
      CONCAT(ct.TenCongTy, N' · ', tn.TenToaNha, N' · ', hd.Thang, '/', hd.Nam) AS name,
      CONVERT(decimal(18,2), SUM(line.SoTien)) AS amount
    FROM dbo.HoaDonThang AS hd
    JOIN dbo.CongTy AS ct ON ct.MaCongTy = hd.MaCongTy
    JOIN dbo.ToaNha AS tn ON tn.MaToaNha = hd.MaToaNha
    JOIN dbo.V_ChiTietHoaDon AS line ON line.MaHoaDon = hd.MaHoaDon
    WHERE hd.TrangThai = 'CHUA_THANH_TOAN'
    GROUP BY hd.MaHoaDon, ct.TenCongTy, tn.TenToaNha, hd.Thang, hd.Nam
    HAVING SUM(line.SoTien) > 0
    ORDER BY hd.MaHoaDon`
};

const writeTables = {
  companies: { table: "CongTy", pk: "MaCongTy", columns: { code: "MaCongTy", name: "TenCongTy", taxCode: "MaSoThue", address: "DiaChi", phone: "DienThoai", email: "Email", sector: "LinhVuc" } },
  offices: { table: "VanPhong", pk: "MaVanPhong", columns: { code: "MaVanPhong", buildingId: "MaToaNha", locationId: "MaViTri", floor: "Tang", area: "DienTich" } },
  contracts: { table: "HopDongThue", pk: "MaHopDong", columns: { code: "MaHopDong", companyId: "MaCongTy", officeId: "MaVanPhong", startDate: "NgayBatDau", endDate: "NgayKetThuc" } },
  services: { table: "DichVu", pk: "MaDichVu", columns: { code: "MaDichVu", buildingId: "MaToaNha", serviceTypeId: "MaLoaiDV", name: "TenDichVu", basePrice: "DonGiaCoBan" } },
  buildingEmployees: { table: "NhanVienToaNha", pk: "MaNVTN", columns: { code: "MaNVTN", buildingId: "MaToaNha", managerId: "MaQuanLy", employeeType: "LoaiNV", name: "HoTen", gender: "GioiTinh", birthDate: "NgaySinh", phone: "DienThoai", email: "Email", startDate: "NgayVaoLam" } },
  companyEmployees: { table: "NhanVienCongTy", pk: "MaNVCT", columns: { code: "MaNVCT", companyId: "MaCongTy", name: "HoTen", gender: "GioiTinh", birthDate: "NgaySinh", phone: "DienThoai", email: "Email", jobTitle: "ChucVu", startDate: "NgayVaoLam", endDate: "NgayNghiViec" } }
};

const invoiceLockQuery = `SELECT 1 AS found FROM dbo.HoaDonThang AS hd WITH (UPDLOCK, HOLDLOCK)
  JOIN dbo.VanPhong AS vp ON vp.MaToaNha = hd.MaToaNha
  WHERE vp.MaVanPhong = @officeId AND hd.MaCongTy = @companyId
    AND DATEFROMPARTS(hd.Nam, hd.Thang, 1) <= COALESCE(CONVERT(date, @endDate, 23), '99991231')
    AND EOMONTH(DATEFROMPARTS(hd.Nam, hd.Thang, 1)) >= CONVERT(date, @startDate, 23)`;

function reportFilters(name, query) {
  const allowed = {
    "company-cost": { companyId: "code", buildingId: "code", from: "month", to: "month" },
    "daily-services": { companyId: "code", buildingId: "code", employeeId: "code", serviceType: "code", from: "date", to: "date" },
    payroll: { buildingId: "code", period: "month" },
    "building-cashflow": { buildingId: "code", from: "date", to: "date" }
  }[name];
  if (!allowed) throw new ValidationError("Báo cáo không tồn tại.");
  const result = {};
  for (const key of Object.keys(query)) if (!Object.hasOwn(allowed, key)) throw new ValidationError(`Bộ lọc ${key} không hợp lệ.`);
  for (const [key, type] of Object.entries(allowed)) {
    const value = query[key];
    if (value === undefined || value === "") { result[key] = null; continue; }
    if (typeof value !== "string") throw new ValidationError(`Bộ lọc ${key} không hợp lệ.`);
    if (type === "code" && !/^[\w-]{1,20}$/.test(value)) throw new ValidationError(`Mã ${key} không hợp lệ.`);
    if (type === "month" && !/^(19\d{2}|[2-9]\d{3})-(0[1-9]|1[0-2])$/.test(value)) throw new ValidationError(`Tháng ${key} không hợp lệ.`);
    if (type === "date" && (!/^\d{4}-\d{2}-\d{2}$/.test(value) || Number.isNaN(Date.parse(`${value}T00:00:00Z`)) || new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) !== value)) throw new ValidationError(`Ngày ${key} không hợp lệ.`);
    result[key] = value;
  }
  if (result.from && result.to && result.from > result.to) throw new ValidationError("Khoảng thời gian không hợp lệ.");
  return result;
}

function bindFilters(request, filters) {
  for (const [key, value] of Object.entries(filters)) request.input(key, sql.VarChar(20), value);
  return request;
}

function summarize(rows, keys, chartKey, chartValue = "amount") {
  const points = new Map();
  for (const row of rows) points.set(row[chartKey], (points.get(row[chartKey]) || 0) + Math.round(amount(row[chartValue]) * 100));
  return {
    summary: keys,
    chart: [...points].sort(([a], [b]) => String(a).localeCompare(String(b))).map(([label, cents]) => ({ label, value: cents / 100 })),
    rows,
    total: rows.length
  };
}

class SqlStore {
  constructor(config = sqlConfig(), driver = sql) {
    this.config = config;
    this.driver = driver;
    this.poolPromise = null;
  }

  async pool() {
    if (!this.poolPromise) {
      this.poolPromise = new this.driver.ConnectionPool(this.config).connect().catch((error) => {
        this.poolPromise = null;
        throw error;
      });
    }
    return this.poolPromise;
  }

  async request(filters = {}) {
    return bindFilters((await this.pool()).request(), filters);
  }

  async health() {
    const result = await (await this.request()).query(`SELECT
      (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0 AND name <> 'sysdiagrams') AS totalTables,
      (SELECT COUNT(*) FROM sys.foreign_keys) AS foreignKeys,
      (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name IN
        ('ThamSo','ViTri','LoaiDichVu','BacCongViec','ToaNha','CongTy','VanPhong',
         'NhanVienCongTy','DichVu','NhanVienToaNha','HoaDonThang','ChiPhiVanHanh',
         'HopDongThue','SuDungDichVu','ChiTietSuDungNV','PhanCongNVTN',
         'ChiTietHoaDon','LuongThang')) AS tableCount,
      CASE WHEN OBJECT_ID('dbo.V_ChiTietHoaDon', 'V') IS NOT NULL THEN 1 ELSE 0 END AS hasInvoiceView,
      CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.HoaDonThang')
        AND name = 'MaHoaDon' AND system_type_id = TYPE_ID('int') AND is_identity = 1) THEN 1 ELSE 0 END AS hasIntInvoiceId,
      CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.ChiTietHoaDon')
        AND name = 'MaHoaDon' AND system_type_id = TYPE_ID('int')) THEN 1 ELSE 0 END AS hasIntDetailInvoiceId,
      CASE WHEN COL_LENGTH('dbo.ChiTietHoaDon', 'SoTien') IS NULL
        AND COL_LENGTH('dbo.V_ChiTietHoaDon', 'SoTien') IS NOT NULL THEN 1 ELSE 0 END AS hasViewAmount,
      CASE WHEN COL_LENGTH('dbo.HoaDonThang', 'TrangThai') IS NOT NULL
        AND COL_LENGTH('dbo.HoaDonThang', 'NgayThanhToan') IS NOT NULL
        AND COL_LENGTH('dbo.HoaDonThang', 'NguoiThu') IS NOT NULL
        AND EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID('dbo.HoaDonThang')
          AND name = 'CK_HoaDonThang_ThanhToan' AND is_disabled = 0 AND is_not_trusted = 0)
        THEN 1 ELSE 0 END AS hasPaymentContract`);
    const state = result.recordset[0];
    if (state.totalTables !== 18 || state.tableCount !== 18 || state.foreignKeys !== 23 ||
        !state.hasInvoiceView || !state.hasIntInvoiceId || !state.hasIntDetailInvoiceId ||
        !state.hasViewAmount || !state.hasPaymentContract) {
      const error = new Error("SQL Server schema does not match the TV3 BCNF handover");
      error.code = "SCHEMA_MISMATCH";
      throw error;
    }
    // TV6 sửa: tách trạng thái thanh toán khỏi bốn procedure khác để không bật nút khi bản TV4 cũ vẫn THROW 51400.
    return { status: "ok", dataMode: "sqlserver", database: this.config.database, schema: "TV3-BCNF-18", readOnly: false,
      transactionsReady: await this.transactionsReady(), paymentReady: await this.paymentReady() };
  }

  async transactionsReady() {
    const result = await (await this.request()).query(`SELECT
      (SELECT COUNT(*) FROM sys.procedures WHERE schema_id = SCHEMA_ID('dbo') AND name IN
        ('USP_Trx_KyHopDongThueMatBang','USP_Trx_GhiNhanDichVuHangNgay',
         'USP_Trx_PhatHanhHoaDonThang','USP_Trx_ChotBangLuongNhanVien')) AS procedures,
      (SELECT COUNT(*) FROM sys.table_types WHERE schema_id = SCHEMA_ID('dbo') AND name IN
        ('TT_DanhSachPhong','TT_DanhSachSuDung')) AS tableTypes,
      (SELECT COUNT(*) FROM sys.triggers WHERE is_disabled = 0 AND name IN
        ('TR_ChiTietThue_ChanTrungLap','TR_DangKyDichVu_ApDungBacThang',
         'TR_NhatKyDichVu_KiemTraHopLe','TR_CongTy_ChanXoa',
         'TR_ToaNha_ChanXoa','TR_ChiTietThue_DongBoDienTich')) AS triggers`);
    const state = result.recordset[0];
    return state.procedures === 4 && state.tableTypes === 2 && state.triggers === 6;
  }

  async paymentReady() {
    // TV6 sửa: bản procedure tương thích phải có logic thanh toán, không phải stub 51400.
    const result = await (await this.request()).query(`SELECT CASE WHEN OBJECT_ID('dbo.USP_Trx_ThanhToanHoaDonVaVaoSoQuy', 'P') IS NOT NULL
      AND OBJECT_DEFINITION(OBJECT_ID('dbo.USP_Trx_ThanhToanHoaDonVaVaoSoQuy', 'P')) LIKE '%@TongTienHoaDon%'
      AND OBJECT_DEFINITION(OBJECT_ID('dbo.USP_Trx_ThanhToanHoaDonVaVaoSoQuy', 'P')) NOT LIKE '%THROW 51400%'
      THEN 1 ELSE 0 END AS ready`);
    return result.recordset[0].ready === 1;
  }

  async lookups() {
    const result = {};
    for (const [key, query] of Object.entries(lookupQueries)) result[key] = (await (await this.request()).query(query)).recordset;
    return result;
  }

  writeConfig(collection, recordOrId) {
    if (collection !== "employees") return writeTables[collection];
    const type = typeof recordOrId === "string" ? recordOrId.split(":", 1)[0] : recordOrId.type;
    if (type === "TN" || type === "building") return writeTables.buildingEmployees;
    if (type === "CT" || type === "company") return writeTables.companyEmployees;
    throw new ValidationError("Loại nhân viên không hợp lệ.");
  }

  async write(collection, record, originalId = null) {
    const config = this.writeConfig(collection, record);
    if (!config) throw new ValidationError("Danh mục không tồn tại.");
    const originalCode = originalId && (collection === "employees" ? originalId.slice(3) : originalId);
    if (originalId && (record.code !== originalCode || this.writeConfig(collection, originalId) !== config))
      throw new ValidationError("Không thể đổi mã hoặc loại nhân viên của bản ghi.");
    const transaction = new this.driver.Transaction(await this.pool());
    await transaction.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);
    let committed = false;
    try {
      const query = async (statement, values = {}) => {
        const request = new this.driver.Request(transaction);
        for (const [key, value] of Object.entries(values)) {
          if (key.endsWith("Date")) request.input(key, sql.Date, value ? value instanceof Date ? value : new Date(`${value}T00:00:00Z`) : null);
          else if (key === "floor") request.input(key, sql.SmallInt, value);
          else if (key === "area") request.input(key, sql.Decimal(10, 2), value);
          else if (key === "basePrice") request.input(key, sql.Decimal(18, 2), value);
          else request.input(key, value);
        }
        return request.query(statement);
      };
      if (originalId) {
        const exists = await query(`SELECT 1 AS found FROM dbo.${config.table} WITH (UPDLOCK, HOLDLOCK) WHERE ${config.pk} = @original`, { original: originalCode });
        if (!exists.recordset.length) { await transaction.rollback(); return null; }
      }
      if (collection === "offices") {
        const building = await query("SELECT SoTang FROM dbo.ToaNha WITH (UPDLOCK, HOLDLOCK) WHERE MaToaNha = @buildingId", { buildingId: record.buildingId });
        if (!building.recordset.length || record.floor > building.recordset[0].SoTang) throw new ValidationError("Tầng văn phòng phải thuộc tòa nhà đã chọn.");
      }
      if (collection === "contracts") {
        const original = originalId ? (await query(`SELECT MaCongTy AS companyId, MaVanPhong AS officeId,
          CONVERT(char(10), NgayBatDau, 23) AS startDate, CONVERT(char(10), NgayKetThuc, 23) AS endDate
          FROM dbo.HopDongThue WHERE MaHopDong = @original`, { original: originalCode })).recordset[0] : null;
        const changed = !original || ["companyId", "officeId", "startDate", "endDate"].some((key) => (original[key] || null) !== (record[key] || null));
        if (changed) {
          for (const period of [original, record].filter(Boolean)) {
            if ((await query(invoiceLockQuery, period)).recordset.length)
              throw new ValidationError("Kỳ đã lập hóa đơn; không thể thay đổi hợp đồng ảnh hưởng kỳ này.");
          }
        }
        const conflict = await query(`SELECT 1 AS found FROM dbo.HopDongThue WITH (UPDLOCK, HOLDLOCK)
          WHERE MaVanPhong = @officeId AND MaHopDong <> @code
            AND NgayBatDau <= COALESCE(CONVERT(date, @endDate, 23), '99991231')
            AND (NgayKetThuc IS NULL OR NgayKetThuc >= CONVERT(date, @startDate, 23))`, record);
        if (conflict.recordset.length) throw new ValidationError("Văn phòng đã có hợp đồng trong khoảng thời gian này.");
      }
      if (collection === "employees" && record.type === "building") {
        if (record.managerId) {
          const manager = await query(`SELECT 1 AS found FROM dbo.NhanVienToaNha WITH (UPDLOCK, HOLDLOCK)
            WHERE MaNVTN = @managerId AND MaToaNha = @buildingId AND LoaiNV = 'QUAN_LY'`, record);
          if (!manager.recordset.length) throw new ValidationError("Quản lý phải thuộc cùng tòa nhà và có loại QUAN_LY.");
        }
        if (originalId) {
          const child = await query("SELECT 1 AS found FROM dbo.NhanVienToaNha WITH (UPDLOCK, HOLDLOCK) WHERE MaQuanLy = @code", { code: record.code });
          if (child.recordset.length) {
            const current = await query("SELECT MaToaNha, LoaiNV FROM dbo.NhanVienToaNha WHERE MaNVTN = @code", { code: record.code });
            if (current.recordset[0].MaToaNha !== record.buildingId || current.recordset[0].LoaiNV !== "QUAN_LY")
              throw new ValidationError("Quản lý đang có cấp dưới không thể đổi tòa hoặc loại nhân viên.");
          }
        }
      }
      const keys = Object.keys(config.columns);
      const values = Object.fromEntries(keys.map((key) => [key, record[key]]));
      const result = originalId
        ? await query(`UPDATE dbo.${config.table} SET ${keys.filter((key) => key !== "code").map((key) => `${config.columns[key]} = @${key}`).join(", ")} WHERE ${config.pk} = @original`, { ...values, original: originalCode })
        : await query(`INSERT dbo.${config.table} (${keys.map((key) => config.columns[key]).join(", ")}) VALUES (${keys.map((key) => `@${key}`).join(", ")})`, values);
      await transaction.commit();
      committed = true;
      if (originalId && !result.rowsAffected[0]) return null;
      const id = collection === "employees" ? `${record.type === "building" ? "TN" : "CT"}:${record.code}` : record.code;
      return (await this.list(collection)).find((row) => row.id === id);
    } catch (error) {
      if (!committed) await transaction.rollback().catch(() => {});
      throw error;
    }
  }

  async remove(collection, id) {
    const config = this.writeConfig(collection, id);
    if (!config || !/^(?:[A-Za-z0-9_-]{1,20}|(?:TN|CT):[A-Za-z0-9_-]{1,20})$/.test(id)) throw new ValidationError("Mã bản ghi không hợp lệ.");
    const code = collection === "employees" ? id.slice(3) : id;
    if (collection === "contracts") {
      const transaction = new this.driver.Transaction(await this.pool());
      await transaction.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);
      try {
        const current = (await new this.driver.Request(transaction).input("code", code).query(`SELECT MaCongTy AS companyId,
          MaVanPhong AS officeId, CONVERT(char(10), NgayBatDau, 23) AS startDate,
          CONVERT(char(10), NgayKetThuc, 23) AS endDate
          FROM dbo.HopDongThue WITH (UPDLOCK, HOLDLOCK) WHERE MaHopDong = @code`)).recordset[0];
        if (!current) { await transaction.rollback(); return false; }
        const check = new this.driver.Request(transaction);
        for (const [key, value] of Object.entries(current)) check.input(key, value);
        if ((await check.query(invoiceLockQuery)).recordset.length)
          throw new ValidationError("Kỳ đã lập hóa đơn; không thể xóa hợp đồng ảnh hưởng kỳ này.");
        const result = await new this.driver.Request(transaction).input("code", code).query("DELETE FROM dbo.HopDongThue WHERE MaHopDong = @code");
        await transaction.commit();
        return Boolean(result.rowsAffected[0]);
      } catch (error) { await transaction.rollback().catch(() => {}); throw error; }
    }
    const result = await (await this.request({ code })).query(`DELETE FROM dbo.${config.table} WHERE ${config.pk} = @code`);
    return Boolean(result.rowsAffected[0]);
  }

  async list(collection) {
    const query = listQueries[collection];
    if (!query) throw new ValidationError("Danh mục không tồn tại.");
    if (collection === "offices") {
      const request = await this.request();
      const result = await request.query(`SELECT COL_LENGTH('dbo.VanPhong', 'TrangThai') AS statusColumn`);
      // TV6 sửa: cột TV5 lưu ảnh chụp DML, còn trạng thái hiển thị phải đúng theo ngày hiện tại.
      const status = result.recordset[0].statusColumn === null
        ? "CAST(NULL AS varchar(20))"
        : `CASE WHEN EXISTS (SELECT 1 FROM dbo.HopDongThue AS lease
            WHERE lease.MaVanPhong = vp.MaVanPhong AND lease.NgayBatDau <= CONVERT(date, GETDATE())
              AND (lease.NgayKetThuc IS NULL OR lease.NgayKetThuc >= CONVERT(date, GETDATE())))
            THEN 'DANG_THUE' ELSE 'TRONG' END`;
      return (await (await this.request()).query(query.replace("OFFICE_STATUS", status))).recordset;
    }
    return (await (await this.request()).query(query)).recordset;
  }

  async report(name, query) {
    const filters = reportFilters(name, query);
    const request = await this.request(filters);
    if (name === "company-cost") {
      const records = (await request.query(`SELECT hd.MaHoaDon, hd.Nam, hd.Thang, ct.TenCongTy AS company,
          ct.MaCongTy, tn.TenToaNha AS building, line.MaChiTiet, line.LoaiKhoan,
          line.MaVanPhong, dv.TenDichVu AS service, line.SoLuong AS quantity,
          line.DonGiaApDung AS unitPrice, line.TyLeNgay AS dayRatio,
          line.SoTien AS amount,
          contract.MaHopDong AS contract
        FROM dbo.HoaDonThang AS hd
        JOIN dbo.CongTy AS ct ON ct.MaCongTy = hd.MaCongTy
        JOIN dbo.ToaNha AS tn ON tn.MaToaNha = hd.MaToaNha
        LEFT JOIN dbo.V_ChiTietHoaDon AS line ON line.MaHoaDon = hd.MaHoaDon
        LEFT JOIN dbo.DichVu AS dv ON dv.MaDichVu = line.MaDichVu
        OUTER APPLY (SELECT TOP (1) lease.MaHopDong FROM dbo.HopDongThue AS lease
          WHERE lease.MaCongTy = hd.MaCongTy AND lease.MaVanPhong = line.MaVanPhong
            AND lease.NgayBatDau <= EOMONTH(DATEFROMPARTS(hd.Nam, hd.Thang, 1))
            AND (lease.NgayKetThuc IS NULL OR lease.NgayKetThuc >= DATEFROMPARTS(hd.Nam, hd.Thang, 1))
          ORDER BY lease.NgayBatDau DESC, lease.MaHopDong) AS contract
        WHERE (@companyId IS NULL OR hd.MaCongTy = @companyId)
          AND (@buildingId IS NULL OR hd.MaToaNha = @buildingId)
          AND (@from IS NULL OR hd.Nam * 100 + hd.Thang >= CONVERT(int, REPLACE(@from, '-', '')))
          AND (@to IS NULL OR hd.Nam * 100 + hd.Thang <= CONVERT(int, REPLACE(@to, '-', '')))
        ORDER BY SUM(COALESCE(line.SoTien, 0)) OVER (PARTITION BY hd.MaHoaDon) DESC,
          ct.TenCongTy, hd.Nam, hd.Thang, hd.MaHoaDon, line.MaChiTiet`)).recordset;
      const rows = records.map((row) => ({ period: periodText(row.Nam, row.Thang),
        company: row.company, building: row.building, invoice: row.MaHoaDon,
        contract: row.contract || "", category: row.LoaiKhoan || "",
        categoryLabel: ({ THUE_VAN_PHONG: "Thuê văn phòng", DICH_VU_THANG: "Dịch vụ tháng",
          DICH_VU_LUOT: "Dịch vụ theo lượt" })[row.LoaiKhoan] || row.LoaiKhoan || "",
        item: row.MaVanPhong || row.service || "", quantity: amount(row.quantity),
        unitPrice: amount(row.unitPrice), dayRatio: amount(row.dayRatio),
        amount: amount(row.amount) }));
      return summarize(rows, {
        totalCost: moneySum(rows),
        rentCost: moneySum(records, (row) => row.LoaiKhoan === "THUE_VAN_PHONG" ? row.amount : 0),
        serviceCost: moneySum(records, (row) => row.LoaiKhoan?.startsWith("DICH_VU_") ? row.amount : 0),
        monthlyServiceCost: moneySum(records, (row) => row.LoaiKhoan === "DICH_VU_THANG" ? row.amount : 0),
        usageServiceCost: moneySum(records, (row) => row.LoaiKhoan === "DICH_VU_LUOT" ? row.amount : 0),
        invoiceCount: new Set(records.map((row) => row.MaHoaDon)).size
      }, "period");
    }
    if (name === "daily-services") {
      const records = (await request.query(`SELECT logdv.MaSuDung, logdv.NgaySuDung,
          nv.MaNVCT, nv.HoTen AS employee, ct.TenCongTy AS company,
          tn.TenToaNha AS building, dv.TenDichVu AS service,
          ldv.MaLoaiDV, ldv.TenLoai AS serviceType, logdv.SoLuot AS quantity,
          logdv.DonGiaApDung AS unitPrice,
          CONVERT(decimal(28,2), logdv.SoLuot * logdv.DonGiaApDung) AS amount
        FROM dbo.ChiTietSuDungNV AS logdv
        JOIN dbo.NhanVienCongTy AS nv ON nv.MaNVCT = logdv.MaNVCT
        JOIN dbo.CongTy AS ct ON ct.MaCongTy = nv.MaCongTy
        JOIN dbo.DichVu AS dv ON dv.MaDichVu = logdv.MaDichVu
        JOIN dbo.ToaNha AS tn ON tn.MaToaNha = dv.MaToaNha
        JOIN dbo.LoaiDichVu AS ldv ON ldv.MaLoaiDV = dv.MaLoaiDV
        WHERE (@companyId IS NULL OR nv.MaCongTy = @companyId)
          AND (@buildingId IS NULL OR dv.MaToaNha = @buildingId)
          AND (@employeeId IS NULL OR nv.MaNVCT = @employeeId)
          AND (@serviceType IS NULL OR ldv.MaLoaiDV = @serviceType)
          AND (@from IS NULL OR logdv.NgaySuDung >= CONVERT(date, @from, 23))
          AND (@to IS NULL OR logdv.NgaySuDung <= CONVERT(date, @to, 23))
        ORDER BY logdv.NgaySuDung, logdv.MaSuDung`)).recordset;
      const rows = records.map((row) => ({ id: row.MaSuDung, date: dateText(row.NgaySuDung),
        company: row.company, building: row.building, employee: row.employee,
        employeeId: row.MaNVCT, service: row.service, serviceType: row.serviceType,
        quantity: row.quantity, unitPrice: amount(row.unitPrice), amount: amount(row.amount) }));
      return summarize(rows, {
        totalUses: rows.reduce((sum, row) => sum + row.quantity, 0),
        totalCost: moneySum(rows),
        mealUses: records.reduce((sum, row) => sum + (row.MaLoaiDV === "AN_UONG" ? row.quantity : 0), 0),
        parkingUses: records.reduce((sum, row) => sum + (row.MaLoaiDV === "GUI_XE" ? row.quantity : 0), 0)
      }, "date");
    }
    if (name === "payroll") {
      const records = (await request.query(`SELECT payroll.MaNVTN, payroll.Nam, payroll.Thang,
          nv.HoTen AS employee, tn.TenToaNha AS building,
          bac.TenBac AS role, dv.TenDichVu AS service,
          payroll.LuongCoBan AS baseSalary, payroll.TienThuong AS bonus,
          payroll.LuongCoBan + payroll.TienThuong AS amount
        FROM dbo.LuongThang AS payroll
        JOIN dbo.NhanVienToaNha AS nv ON nv.MaNVTN = payroll.MaNVTN
        JOIN dbo.ToaNha AS tn ON tn.MaToaNha = nv.MaToaNha
        JOIN dbo.PhanCongNVTN AS assignment ON assignment.MaNVTN = payroll.MaNVTN
          AND assignment.Thang = payroll.Thang AND assignment.Nam = payroll.Nam
        JOIN dbo.BacCongViec AS bac ON bac.MaBac = assignment.MaBac
        LEFT JOIN dbo.DichVu AS dv ON dv.MaDichVu = assignment.MaDichVu
        WHERE (@buildingId IS NULL OR nv.MaToaNha = @buildingId)
          AND (@period IS NULL OR payroll.Nam * 100 + payroll.Thang = CONVERT(int, REPLACE(@period, '-', '')))
        ORDER BY payroll.Nam, payroll.Thang, payroll.MaNVTN`)).recordset;
      const revenueRequest = await this.request(filters);
      const revenue = (await revenueRequest.query(`SELECT COALESCE(SUM(line.SoTien), 0) AS serviceRevenue
        FROM dbo.V_ChiTietHoaDon AS line
        JOIN dbo.HoaDonThang AS hd ON hd.MaHoaDon = line.MaHoaDon
        WHERE line.LoaiKhoan IN ('DICH_VU_THANG', 'DICH_VU_LUOT')
          AND (@buildingId IS NULL OR hd.MaToaNha = @buildingId)
          AND (@period IS NULL OR hd.Nam * 100 + hd.Thang = CONVERT(int, REPLACE(@period, '-', '')))`)).recordset[0];
      const rows = records.map((row) => ({ period: periodText(row.Nam, row.Thang),
        employeeId: row.MaNVTN, employee: row.employee, building: row.building,
        role: row.role, service: row.service || "", baseSalary: amount(row.baseSalary),
        bonus: amount(row.bonus), amount: amount(row.amount) }));
      const totalPayroll = moneySum(rows);
      return summarize(rows, { totalPayroll, basePayroll: moneySum(rows, (row) => row.baseSalary),
        totalBonus: moneySum(rows, (row) => row.bonus),
        employeeCount: new Set(records.map((row) => row.MaNVTN)).size,
        averagePayroll: rows.length ? totalPayroll / rows.length : 0, serviceRevenue: amount(revenue.serviceRevenue) }, "period");
    }
    const records = (await request.query(`SELECT CONVERT(char(10), hd.NgayThanhToan, 23) AS date,
        CONVERT(char(7), DATEFROMPARTS(hd.Nam, hd.Thang, 1), 23) AS period,
        tn.TenToaNha AS building, N'Thu' AS type,
        CONCAT(N'Hóa đơn #', hd.MaHoaDon) AS reference,
        ct.TenCongTy AS counterparty, N'Hóa đơn đã thanh toán' AS description,
        N'Ngày thanh toán' AS dateBasis,
        COALESCE(SUM(line.SoTien), 0) AS amount
      FROM dbo.HoaDonThang AS hd
      JOIN dbo.CongTy AS ct ON ct.MaCongTy = hd.MaCongTy
      JOIN dbo.ToaNha AS tn ON tn.MaToaNha = hd.MaToaNha
      LEFT JOIN dbo.V_ChiTietHoaDon AS line ON line.MaHoaDon = hd.MaHoaDon
      WHERE hd.TrangThai = 'DA_THANH_TOAN'
        AND (@buildingId IS NULL OR hd.MaToaNha = @buildingId)
        AND (@from IS NULL OR hd.NgayThanhToan >= CONVERT(date, @from, 23))
        AND (@to IS NULL OR hd.NgayThanhToan <= CONVERT(date, @to, 23))
      GROUP BY hd.MaHoaDon, hd.NgayThanhToan, hd.Thang, hd.Nam,
        tn.TenToaNha, ct.TenCongTy
      UNION ALL
      SELECT CONVERT(char(10), DATEFROMPARTS(cost.Nam, cost.Thang, 1), 23),
        CONVERT(char(7), DATEFROMPARTS(cost.Nam, cost.Thang, 1), 23),
        tn.TenToaNha, N'Chi', CONCAT(N'Chi phí #', cost.MaChiPhi),
        CAST(NULL AS nvarchar(150)), cost.LoaiChiPhi, N'Đầu kỳ kế toán', -cost.SoTien
      FROM dbo.ChiPhiVanHanh AS cost
      JOIN dbo.ToaNha AS tn ON tn.MaToaNha = cost.MaToaNha
      WHERE (@buildingId IS NULL OR cost.MaToaNha = @buildingId)
        AND (@from IS NULL OR DATEFROMPARTS(cost.Nam, cost.Thang, 1) >= CONVERT(date, @from, 23))
        AND (@to IS NULL OR DATEFROMPARTS(cost.Nam, cost.Thang, 1) <= CONVERT(date, @to, 23))
      UNION ALL
      SELECT CONVERT(char(10), DATEFROMPARTS(payroll.Nam, payroll.Thang, 1), 23),
        CONVERT(char(7), DATEFROMPARTS(payroll.Nam, payroll.Thang, 1), 23),
        tn.TenToaNha, N'Chi', CONCAT(N'Lương ', payroll.MaNVTN),
        nv.HoTen, N'Lương tháng', N'Đầu kỳ kế toán',
        -(payroll.LuongCoBan + payroll.TienThuong)
      FROM dbo.LuongThang AS payroll
      JOIN dbo.NhanVienToaNha AS nv ON nv.MaNVTN = payroll.MaNVTN
      JOIN dbo.ToaNha AS tn ON tn.MaToaNha = nv.MaToaNha
      WHERE (@buildingId IS NULL OR nv.MaToaNha = @buildingId)
        AND (@from IS NULL OR DATEFROMPARTS(payroll.Nam, payroll.Thang, 1) >= CONVERT(date, @from, 23))
        AND (@to IS NULL OR DATEFROMPARTS(payroll.Nam, payroll.Thang, 1) <= CONVERT(date, @to, 23))
      ORDER BY date, type, reference`)).recordset;
    const rows = records.map((row) => ({ ...row, amount: amount(row.amount) }));
    const totalIncome = moneySum(rows, (row) => Math.max(0, row.amount));
    const totalExpense = moneySum(rows, (row) => Math.max(0, -row.amount));
    return summarize(rows, { totalIncome, totalExpense,
      netCashflow: Math.round((totalIncome - totalExpense) * 100) / 100,
      entryCount: rows.length }, "date");
  }
}

module.exports = { SqlStore, ValidationError, sqlConfig, reportFilters };
