const mysql = require("mysql2/promise");

class ValidationError extends Error {}

const dateText = (value) => value instanceof Date ? value.toISOString().slice(0, 10) : String(value || "").slice(0, 10);
const periodText = (year, month) => `${year}-${String(month).padStart(2, "0")}`;
const amount = (value) => Number(value || 0);
const moneySum = (rows, select = (row) => row.amount) =>
  rows.reduce((cents, row) => cents + Math.round(amount(select(row)) * 100), 0) / 100;

// mysql2 dùng collation mặc định utf8mb4_general_ci; đặt lại theo CSDL để literal trong UNION không xung đột.
const SESSION_COLLATION = "SET NAMES utf8mb4 COLLATE utf8mb4_0900_as_ci";

const TV3_TABLES = ["ThamSo", "ViTri", "LoaiDichVu", "BacCongViec", "ToaNha", "CongTy", "VanPhong",
  "NhanVienCongTy", "DichVu", "NhanVienToaNha", "HoaDonThang", "ChiPhiVanHanh",
  "HopDongThue", "SuDungDichVu", "ChiTietSuDungNV", "PhanCongNVTN", "ChiTietHoaDon", "LuongThang"];
const TV4_PROCEDURES = ["USP_Trx_KyHopDongThueMatBang", "USP_Trx_GhiNhanDichVuHangNgay",
  "USP_Trx_PhatHanhHoaDonThang", "USP_Trx_ChotBangLuongNhanVien"];
const TV5_TRIGGERS = ["TR_ChiTietThue_ChanTrungLap_Ins", "TR_ChiTietThue_ChanTrungLap_Upd",
  "TR_DangKyDichVu_ApDungBacThang", "TR_NhatKyDichVu_KiemTraHopLe_Ins", "TR_NhatKyDichVu_KiemTraHopLe_Upd",
  "TR_CongTy_ChanXoa", "TR_ToaNha_ChanXoa",
  "TR_ChiTietThue_DongBoDienTich_Ins", "TR_ChiTietThue_DongBoDienTich_Upd", "TR_ChiTietThue_DongBoDienTich_Del"];
const inList = (values) => values.map((value) => `'${value}'`).join(", ");

function mysqlConfig(environment = process.env) {
  const required = ["DB_SERVER", "DB_DATABASE", "DB_USER", "DB_PASSWORD"];
  const missing = required.filter((name) => !environment[name]);
  if (missing.length) throw new Error(`Missing MySQL configuration: ${missing.join(", ")}`);
  const port = Number(environment.DB_PORT || 3306);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error("DB_PORT must be a valid TCP port");
  return {
    host: environment.DB_SERVER,
    port,
    database: environment.DB_DATABASE,
    user: environment.DB_USER,
    password: environment.DB_PASSWORD,
    charset: "utf8mb4",
    dateStrings: true,
    decimalNumbers: true,
    connectionLimit: 10,
    connectTimeout: 5000
  };
}

// mysql2 không hỗ trợ tham số đặt tên: đổi @ten thành ? theo đúng thứ tự xuất hiện.
// Tham số thiếu được truyền NULL, nên mọi bộ lọc tùy chọn dùng dạng "@x IS NULL OR ...".
function positional(statement, values = {}) {
  const args = [];
  const text = statement.replace(/@(\w+)/g, (_, name) => {
    args.push(values[name] ?? null);
    return "?";
  });
  return { text, args };
}

const listQueries = {
  companies: `SELECT MaCongTy AS id, MaCongTy AS code, TenCongTy AS name,
      MaSoThue AS taxCode, DiaChi AS address, DienThoai AS phone, Email AS email, LinhVuc AS sector
    FROM CongTy ORDER BY MaCongTy`,
  offices: `SELECT vp.MaVanPhong AS id, vp.MaVanPhong AS code, vp.MaToaNha AS buildingId,
      tn.TenToaNha AS building, vp.MaViTri AS locationId, vt.TenViTri AS location,
      vp.Tang AS floor, vp.DienTich AS area, OFFICE_STATUS AS status
    FROM VanPhong AS vp JOIN ToaNha AS tn ON tn.MaToaNha = vp.MaToaNha
    JOIN ViTri AS vt ON vt.MaViTri = vp.MaViTri
    ORDER BY vp.MaVanPhong`,
  contracts: `SELECT hd.MaHopDong AS id, hd.MaHopDong AS code, hd.MaCongTy AS companyId,
      ct.TenCongTy AS company, hd.MaVanPhong AS officeId,
      DATE_FORMAT(hd.NgayBatDau, '%Y-%m-%d') AS startDate,
      DATE_FORMAT(hd.NgayKetThuc, '%Y-%m-%d') AS endDate
    FROM HopDongThue AS hd JOIN CongTy AS ct ON ct.MaCongTy = hd.MaCongTy
    ORDER BY hd.MaHopDong`,
  services: `SELECT dv.MaDichVu AS id, dv.MaDichVu AS code, dv.MaToaNha AS buildingId,
      tn.TenToaNha AS building, dv.MaLoaiDV AS serviceTypeId, ldv.TenLoai AS serviceType,
      dv.TenDichVu AS name, dv.DonGiaCoBan AS basePrice
    FROM DichVu AS dv JOIN LoaiDichVu AS ldv ON ldv.MaLoaiDV = dv.MaLoaiDV
    JOIN ToaNha AS tn ON tn.MaToaNha = dv.MaToaNha
    ORDER BY dv.MaDichVu`,
  employees: `SELECT CONCAT('TN:', nv.MaNVTN) AS id, 'building' AS type,
      nv.MaNVTN AS code, nv.HoTen AS name, nv.GioiTinh AS gender,
      DATE_FORMAT(nv.NgaySinh, '%Y-%m-%d') AS birthDate, nv.DienThoai AS phone,
      nv.Email AS email, DATE_FORMAT(nv.NgayVaoLam, '%Y-%m-%d') AS startDate,
      CAST(NULL AS CHAR(10)) AS endDate, CAST(NULL AS CHAR(20)) AS companyId,
      CAST(NULL AS CHAR(200)) AS company, nv.MaToaNha AS buildingId,
      tn.TenToaNha AS building, nv.MaQuanLy AS managerId, nv.LoaiNV AS employeeType,
      CAST(NULL AS CHAR(100)) AS jobTitle
    FROM NhanVienToaNha AS nv JOIN ToaNha AS tn ON tn.MaToaNha = nv.MaToaNha
    UNION ALL
    SELECT CONCAT('CT:', nv.MaNVCT), 'company', nv.MaNVCT, nv.HoTen, nv.GioiTinh,
      DATE_FORMAT(nv.NgaySinh, '%Y-%m-%d'), nv.DienThoai, nv.Email,
      DATE_FORMAT(nv.NgayVaoLam, '%Y-%m-%d'), DATE_FORMAT(nv.NgayNghiViec, '%Y-%m-%d'),
      nv.MaCongTy, ct.TenCongTy, CAST(NULL AS CHAR(20)), CAST(NULL AS CHAR(150)),
      CAST(NULL AS CHAR(20)), CAST(NULL AS CHAR(10)), nv.ChucVu
    FROM NhanVienCongTy AS nv JOIN CongTy AS ct ON ct.MaCongTy = nv.MaCongTy
    ORDER BY type, code`
};

const lookupQueries = {
  buildings: `SELECT MaToaNha AS id, TenToaNha AS name, SoTang AS floors FROM ToaNha ORDER BY TenToaNha`,
  locations: `SELECT MaViTri AS id, TenViTri AS name FROM ViTri ORDER BY TenViTri`,
  serviceTypes: `SELECT MaLoaiDV AS id, TenLoai AS name, KieuTinhPhi AS billingType FROM LoaiDichVu ORDER BY TenLoai`,
  companies: `SELECT MaCongTy AS id, TenCongTy AS name FROM CongTy ORDER BY TenCongTy`,
  companyEmployees: `SELECT MaNVCT AS id, HoTen AS name, MaCongTy AS companyId
    FROM NhanVienCongTy ORDER BY HoTen, MaNVCT`,
  offices: `SELECT MaVanPhong AS id, MaVanPhong AS name, MaToaNha AS buildingId FROM VanPhong ORDER BY MaVanPhong`,
  managers: `SELECT MaNVTN AS id, HoTen AS name, MaToaNha AS buildingId FROM NhanVienToaNha WHERE LoaiNV = 'QUAN_LY' ORDER BY HoTen`,
  // TV6 sửa: thanh toán chỉ chọn hóa đơn chưa trả và dùng đúng tổng tiền từ view TV3.
  unpaidInvoices: `SELECT hd.MaHoaDon AS id,
      CONCAT(ct.TenCongTy, ' · ', tn.TenToaNha, ' · ', hd.Thang, '/', hd.Nam) AS name,
      CAST(SUM(line.SoTien) AS DECIMAL(18,2)) AS amount
    FROM HoaDonThang AS hd
    JOIN CongTy AS ct ON ct.MaCongTy = hd.MaCongTy
    JOIN ToaNha AS tn ON tn.MaToaNha = hd.MaToaNha
    JOIN V_ChiTietHoaDon AS line ON line.MaHoaDon = hd.MaHoaDon
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

// Khóa lịch hóa đơn: UPDATE/DELETE hợp đồng không được chạm kỳ đã lập hóa đơn.
const invoiceLockQuery = `SELECT 1 AS found FROM HoaDonThang AS hd
  JOIN VanPhong AS vp ON vp.MaToaNha = hd.MaToaNha
  WHERE vp.MaVanPhong = @officeId AND hd.MaCongTy = @companyId
    AND MAKEDATE(hd.Nam, 1) + INTERVAL (hd.Thang - 1) MONTH <= COALESCE(@endDate, DATE '9999-12-31')
    AND LAST_DAY(MAKEDATE(hd.Nam, 1) + INTERVAL (hd.Thang - 1) MONTH) >= @startDate`;

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
  constructor(config = mysqlConfig()) {
    this.config = config;
    this.connectionPool = null;
  }

  pool() {
    if (!this.connectionPool) {
      this.connectionPool = mysql.createPool(this.config);
      this.connectionPool.pool.on("connection", (connection) => connection.query(SESSION_COLLATION));
    }
    return this.connectionPool;
  }

  async close() {
    if (this.connectionPool) await this.connectionPool.end();
    this.connectionPool = null;
  }

  async query(statement, values = {}) {
    const { text, args } = positional(statement, values);
    const [rows] = await this.pool().query(text, args);
    return rows;
  }

  // Chạy trong một transaction SERIALIZABLE; trả về kết quả của `work`, rollback nếu lỗi.
  async withTransaction(work) {
    const connection = await this.pool().getConnection();
    try {
      await connection.query("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE");
      await connection.beginTransaction();
      const result = await work(async (statement, values = {}) => {
        const { text, args } = positional(statement, values);
        return (await connection.query(text, args))[0];
      });
      await connection.commit();
      return result;
    } catch (error) {
      await connection.rollback().catch(() => {});
      throw error;
    } finally {
      connection.release();
    }
  }

  async health() {
    const [state] = await this.query(`SELECT
      (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE') AS totalTables,
      (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = DATABASE()) AS foreignKeys,
      (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE'
        AND TABLE_NAME IN (${inList(TV3_TABLES)})) AS tableCount,
      (SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'V_ChiTietHoaDon') AS hasInvoiceView,
      (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'HoaDonThang'
        AND COLUMN_NAME = 'MaHoaDon' AND DATA_TYPE = 'int' AND EXTRA LIKE '%auto_increment%') AS hasIntInvoiceId,
      (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ChiTietHoaDon'
        AND COLUMN_NAME = 'MaHoaDon' AND DATA_TYPE = 'int') AS hasIntDetailInvoiceId,
      (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ChiTietHoaDon'
        AND COLUMN_NAME = 'SoTien') AS detailAmountColumns,
      (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'V_ChiTietHoaDon'
        AND COLUMN_NAME = 'SoTien') AS viewAmountColumns,
      (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'HoaDonThang'
        AND COLUMN_NAME IN ('TrangThai', 'NgayThanhToan', 'NguoiThu')) AS paymentColumns,
      (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'HoaDonThang'
        AND CONSTRAINT_NAME = 'CK_HoaDonThang_ThanhToan' AND CONSTRAINT_TYPE = 'CHECK') AS paymentCheck`);
    const schemaOk = state.totalTables === 18 && state.tableCount === 18 && state.foreignKeys === 23 &&
      state.hasInvoiceView === 1 && state.hasIntInvoiceId === 1 && state.hasIntDetailInvoiceId === 1 &&
      state.detailAmountColumns === 0 && state.viewAmountColumns === 1 && state.paymentColumns === 3 && state.paymentCheck === 1;
    if (!schemaOk) {
      const error = new Error("MySQL schema does not match the TV3 BCNF handover");
      error.code = "SCHEMA_MISMATCH";
      throw error;
    }
    // TV6 sửa: tách trạng thái thanh toán khỏi các procedure khác để không bật nút khi bản TV4 cũ chưa có.
    return { status: "ok", dataMode: "mysql", database: this.config.database, schema: "TV3-BCNF-18", readOnly: false,
      transactionsReady: await this.transactionsReady(), paymentReady: await this.paymentReady() };
  }

  async transactionsReady() {
    const [state] = await this.query(`SELECT
      (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_TYPE = 'PROCEDURE'
        AND ROUTINE_NAME IN (${inList(TV4_PROCEDURES)})) AS procedures,
      (SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = DATABASE()
        AND TRIGGER_NAME IN (${inList(TV5_TRIGGERS)})) AS triggers`);
    return state.procedures === 4 && state.triggers === 10;
  }

  async paymentReady() {
    // TV6 sửa: bản procedure tương thích phải có tham số số tiền, không phải bản cũ.
    const [state] = await this.query(`SELECT COUNT(*) AS ready FROM information_schema.PARAMETERS
      WHERE SPECIFIC_SCHEMA = DATABASE() AND SPECIFIC_NAME = 'USP_Trx_ThanhToanHoaDonVaVaoSoQuy' AND PARAMETER_NAME = 'p_SoTien'`);
    return state.ready === 1;
  }

  async lookups() {
    const result = {};
    for (const [key, query] of Object.entries(lookupQueries)) result[key] = await this.query(query);
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
    const id = await this.withTransaction(async (run) => {
      if (originalId) {
        const exists = await run(`SELECT 1 AS found FROM ${config.table} WHERE ${config.pk} = @original FOR UPDATE`, { original: originalCode });
        if (!exists.length) return null;
      }
      if (collection === "offices") {
        const [building] = await run("SELECT SoTang FROM ToaNha WHERE MaToaNha = @buildingId FOR UPDATE", { buildingId: record.buildingId });
        if (!building || record.floor > building.SoTang) throw new ValidationError("Tầng văn phòng phải thuộc tòa nhà đã chọn.");
      }
      if (collection === "contracts") {
        const [original] = originalId ? await run(`SELECT MaCongTy AS companyId, MaVanPhong AS officeId,
          DATE_FORMAT(NgayBatDau, '%Y-%m-%d') AS startDate, DATE_FORMAT(NgayKetThuc, '%Y-%m-%d') AS endDate
          FROM HopDongThue WHERE MaHopDong = @original FOR UPDATE`, { original: originalCode }) : [null];
        const changed = !original || ["companyId", "officeId", "startDate", "endDate"].some((key) => (original[key] || null) !== (record[key] || null));
        if (changed) {
          for (const period of [original, record].filter(Boolean)) {
            if ((await run(invoiceLockQuery, period)).length)
              throw new ValidationError("Kỳ đã lập hóa đơn; không thể thay đổi hợp đồng ảnh hưởng kỳ này.");
          }
        }
        const conflict = await run(`SELECT 1 AS found FROM HopDongThue
          WHERE MaVanPhong = @officeId AND MaHopDong <> @code
            AND NgayBatDau <= COALESCE(@endDate, DATE '9999-12-31')
            AND (NgayKetThuc IS NULL OR NgayKetThuc >= @startDate)
          FOR UPDATE`, record);
        if (conflict.length) throw new ValidationError("Văn phòng đã có hợp đồng trong khoảng thời gian này.");
      }
      if (collection === "employees" && record.type === "building") {
        if (record.managerId) {
          const manager = await run(`SELECT 1 AS found FROM NhanVienToaNha
            WHERE MaNVTN = @managerId AND MaToaNha = @buildingId AND LoaiNV = 'QUAN_LY' FOR UPDATE`, record);
          if (!manager.length) throw new ValidationError("Quản lý phải thuộc cùng tòa nhà và có loại QUAN_LY.");
        }
        if (originalId) {
          const child = await run("SELECT 1 AS found FROM NhanVienToaNha WHERE MaQuanLy = @code FOR UPDATE", { code: record.code });
          if (child.length) {
            const [current] = await run("SELECT MaToaNha, LoaiNV FROM NhanVienToaNha WHERE MaNVTN = @code", { code: record.code });
            if (current.MaToaNha !== record.buildingId || current.LoaiNV !== "QUAN_LY")
              throw new ValidationError("Quản lý đang có cấp dưới không thể đổi tòa hoặc loại nhân viên.");
          }
        }
      }
      const keys = Object.keys(config.columns);
      const values = Object.fromEntries(keys.map((key) => [key, record[key]]));
      const result = originalId
        ? await run(`UPDATE ${config.table} SET ${keys.filter((key) => key !== "code").map((key) => `${config.columns[key]} = @${key}`).join(", ")} WHERE ${config.pk} = @original`, { ...values, original: originalCode })
        : await run(`INSERT INTO ${config.table} (${keys.map((key) => config.columns[key]).join(", ")}) VALUES (${keys.map((key) => `@${key}`).join(", ")})`, values);
      if (originalId && !result.affectedRows) return null;
      return collection === "employees" ? `${record.type === "building" ? "TN" : "CT"}:${record.code}` : record.code;
    });
    if (id === null) return null;
    return (await this.list(collection)).find((row) => row.id === id);
  }

  async remove(collection, id) {
    const config = this.writeConfig(collection, id);
    if (!config || !/^(?:[A-Za-z0-9_-]{1,20}|(?:TN|CT):[A-Za-z0-9_-]{1,20})$/.test(id)) throw new ValidationError("Mã bản ghi không hợp lệ.");
    const code = collection === "employees" ? id.slice(3) : id;
    if (collection === "contracts") {
      return this.withTransaction(async (run) => {
        const [current] = await run(`SELECT MaCongTy AS companyId, MaVanPhong AS officeId,
          DATE_FORMAT(NgayBatDau, '%Y-%m-%d') AS startDate, DATE_FORMAT(NgayKetThuc, '%Y-%m-%d') AS endDate
          FROM HopDongThue WHERE MaHopDong = @code FOR UPDATE`, { code });
        if (!current) return false;
        if ((await run(invoiceLockQuery, current)).length)
          throw new ValidationError("Kỳ đã lập hóa đơn; không thể xóa hợp đồng ảnh hưởng kỳ này.");
        const result = await run("DELETE FROM HopDongThue WHERE MaHopDong = @code", { code });
        return Boolean(result.affectedRows);
      });
    }
    const result = await this.withTransaction((run) => run(`DELETE FROM ${config.table} WHERE ${config.pk} = @code`, { code }));
    return Boolean(result.affectedRows);
  }

  async list(collection) {
    const query = listQueries[collection];
    if (!query) throw new ValidationError("Danh mục không tồn tại.");
    if (collection === "offices") {
      const [result] = await this.query(`SELECT COUNT(*) AS statusColumn FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'VanPhong' AND COLUMN_NAME = 'TrangThai'`);
      // TV6 sửa: cột TV5 lưu ảnh chụp DML, còn trạng thái hiển thị phải đúng theo ngày hiện tại.
      const status = result.statusColumn === 0
        ? "CAST(NULL AS CHAR(20))"
        : `CASE WHEN EXISTS (SELECT 1 FROM HopDongThue AS lease
            WHERE lease.MaVanPhong = vp.MaVanPhong AND lease.NgayBatDau <= CURDATE()
              AND (lease.NgayKetThuc IS NULL OR lease.NgayKetThuc >= CURDATE()))
            THEN 'DANG_THUE' ELSE 'TRONG' END`;
      return this.query(query.replace("OFFICE_STATUS", status));
    }
    return this.query(query);
  }

  async report(name, query) {
    const filters = reportFilters(name, query);
    if (name === "company-cost") {
      const records = await this.query(`SELECT hd.MaHoaDon, hd.Nam, hd.Thang, ct.TenCongTy AS company,
          ct.MaCongTy, tn.TenToaNha AS building, line.MaChiTiet, line.LoaiKhoan,
          line.MaVanPhong, dv.TenDichVu AS service, line.SoLuong AS quantity,
          line.DonGiaApDung AS unitPrice, line.TyLeNgay AS dayRatio,
          line.SoTien AS amount,
          contract.MaHopDong AS contract
        FROM HoaDonThang AS hd
        JOIN CongTy AS ct ON ct.MaCongTy = hd.MaCongTy
        JOIN ToaNha AS tn ON tn.MaToaNha = hd.MaToaNha
        LEFT JOIN V_ChiTietHoaDon AS line ON line.MaHoaDon = hd.MaHoaDon
        LEFT JOIN DichVu AS dv ON dv.MaDichVu = line.MaDichVu
        LEFT JOIN LATERAL (
          SELECT lease.MaHopDong FROM HopDongThue AS lease
          WHERE lease.MaCongTy = hd.MaCongTy AND lease.MaVanPhong = line.MaVanPhong
            AND lease.NgayBatDau <= LAST_DAY(MAKEDATE(hd.Nam, 1) + INTERVAL (hd.Thang - 1) MONTH)
            AND (lease.NgayKetThuc IS NULL OR lease.NgayKetThuc >= MAKEDATE(hd.Nam, 1) + INTERVAL (hd.Thang - 1) MONTH)
          ORDER BY lease.NgayBatDau DESC, lease.MaHopDong LIMIT 1
        ) AS contract ON TRUE
        WHERE (@companyId IS NULL OR hd.MaCongTy = @companyId)
          AND (@buildingId IS NULL OR hd.MaToaNha = @buildingId)
          AND (@from IS NULL OR hd.Nam * 100 + hd.Thang >= CAST(REPLACE(@from, '-', '') AS SIGNED))
          AND (@to IS NULL OR hd.Nam * 100 + hd.Thang <= CAST(REPLACE(@to, '-', '') AS SIGNED))
        ORDER BY SUM(COALESCE(line.SoTien, 0)) OVER (PARTITION BY hd.MaHoaDon) DESC,
          ct.TenCongTy, hd.Nam, hd.Thang, hd.MaHoaDon, line.MaChiTiet`, filters);
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
      const records = await this.query(`SELECT logdv.MaSuDung, logdv.NgaySuDung,
          nv.MaNVCT, nv.HoTen AS employee, ct.TenCongTy AS company,
          tn.TenToaNha AS building, dv.TenDichVu AS service,
          ldv.MaLoaiDV, ldv.TenLoai AS serviceType, logdv.SoLuot AS quantity,
          logdv.DonGiaApDung AS unitPrice,
          CAST(logdv.SoLuot * logdv.DonGiaApDung AS DECIMAL(28,2)) AS amount
        FROM ChiTietSuDungNV AS logdv
        JOIN NhanVienCongTy AS nv ON nv.MaNVCT = logdv.MaNVCT
        JOIN CongTy AS ct ON ct.MaCongTy = nv.MaCongTy
        JOIN DichVu AS dv ON dv.MaDichVu = logdv.MaDichVu
        JOIN ToaNha AS tn ON tn.MaToaNha = dv.MaToaNha
        JOIN LoaiDichVu AS ldv ON ldv.MaLoaiDV = dv.MaLoaiDV
        WHERE (@companyId IS NULL OR nv.MaCongTy = @companyId)
          AND (@buildingId IS NULL OR dv.MaToaNha = @buildingId)
          AND (@employeeId IS NULL OR nv.MaNVCT = @employeeId)
          AND (@serviceType IS NULL OR ldv.MaLoaiDV = @serviceType)
          AND (@from IS NULL OR logdv.NgaySuDung >= @from)
          AND (@to IS NULL OR logdv.NgaySuDung <= @to)
        ORDER BY logdv.NgaySuDung, logdv.MaSuDung`, filters);
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
      const records = await this.query(`SELECT payroll.MaNVTN, payroll.Nam, payroll.Thang,
          nv.HoTen AS employee, tn.TenToaNha AS building,
          bac.TenBac AS role, dv.TenDichVu AS service,
          payroll.LuongCoBan AS baseSalary, payroll.TienThuong AS bonus,
          payroll.LuongCoBan + payroll.TienThuong AS amount
        FROM LuongThang AS payroll
        JOIN NhanVienToaNha AS nv ON nv.MaNVTN = payroll.MaNVTN
        JOIN ToaNha AS tn ON tn.MaToaNha = nv.MaToaNha
        JOIN PhanCongNVTN AS assignment ON assignment.MaNVTN = payroll.MaNVTN
          AND assignment.Thang = payroll.Thang AND assignment.Nam = payroll.Nam
        JOIN BacCongViec AS bac ON bac.MaBac = assignment.MaBac
        LEFT JOIN DichVu AS dv ON dv.MaDichVu = assignment.MaDichVu
        WHERE (@buildingId IS NULL OR nv.MaToaNha = @buildingId)
          AND (@period IS NULL OR payroll.Nam * 100 + payroll.Thang = CAST(REPLACE(@period, '-', '') AS SIGNED))
        ORDER BY payroll.Nam, payroll.Thang, payroll.MaNVTN`, filters);
      const [revenue] = await this.query(`SELECT COALESCE(SUM(line.SoTien), 0) AS serviceRevenue
        FROM V_ChiTietHoaDon AS line
        JOIN HoaDonThang AS hd ON hd.MaHoaDon = line.MaHoaDon
        WHERE line.LoaiKhoan IN ('DICH_VU_THANG', 'DICH_VU_LUOT')
          AND (@buildingId IS NULL OR hd.MaToaNha = @buildingId)
          AND (@period IS NULL OR hd.Nam * 100 + hd.Thang = CAST(REPLACE(@period, '-', '') AS SIGNED))`, filters);
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
    const records = await this.query(`SELECT DATE_FORMAT(hd.NgayThanhToan, '%Y-%m-%d') AS date,
        DATE_FORMAT(MAKEDATE(hd.Nam, 1) + INTERVAL (hd.Thang - 1) MONTH, '%Y-%m') AS period,
        tn.TenToaNha AS building, 'Thu' AS type,
        CONCAT('Hóa đơn #', hd.MaHoaDon) AS reference,
        ct.TenCongTy AS counterparty, 'Hóa đơn đã thanh toán' AS description,
        'Ngày thanh toán' AS dateBasis,
        COALESCE(SUM(line.SoTien), 0) AS amount
      FROM HoaDonThang AS hd
      JOIN CongTy AS ct ON ct.MaCongTy = hd.MaCongTy
      JOIN ToaNha AS tn ON tn.MaToaNha = hd.MaToaNha
      LEFT JOIN V_ChiTietHoaDon AS line ON line.MaHoaDon = hd.MaHoaDon
      WHERE hd.TrangThai = 'DA_THANH_TOAN'
        AND (@buildingId IS NULL OR hd.MaToaNha = @buildingId)
        AND (@from IS NULL OR hd.NgayThanhToan >= @from)
        AND (@to IS NULL OR hd.NgayThanhToan <= @to)
      GROUP BY hd.MaHoaDon, hd.NgayThanhToan, hd.Thang, hd.Nam,
        tn.TenToaNha, ct.TenCongTy
      UNION ALL
      SELECT DATE_FORMAT(MAKEDATE(cost.Nam, 1) + INTERVAL (cost.Thang - 1) MONTH, '%Y-%m-%d'),
        DATE_FORMAT(MAKEDATE(cost.Nam, 1) + INTERVAL (cost.Thang - 1) MONTH, '%Y-%m'),
        tn.TenToaNha, 'Chi', CONCAT('Chi phí #', cost.MaChiPhi),
        CAST(NULL AS CHAR(150)), cost.LoaiChiPhi, 'Đầu kỳ kế toán', -cost.SoTien
      FROM ChiPhiVanHanh AS cost
      JOIN ToaNha AS tn ON tn.MaToaNha = cost.MaToaNha
      WHERE (@buildingId IS NULL OR cost.MaToaNha = @buildingId)
        AND (@from IS NULL OR MAKEDATE(cost.Nam, 1) + INTERVAL (cost.Thang - 1) MONTH >= @from)
        AND (@to IS NULL OR MAKEDATE(cost.Nam, 1) + INTERVAL (cost.Thang - 1) MONTH <= @to)
      UNION ALL
      SELECT DATE_FORMAT(MAKEDATE(payroll.Nam, 1) + INTERVAL (payroll.Thang - 1) MONTH, '%Y-%m-%d'),
        DATE_FORMAT(MAKEDATE(payroll.Nam, 1) + INTERVAL (payroll.Thang - 1) MONTH, '%Y-%m'),
        tn.TenToaNha, 'Chi', CONCAT('Lương ', payroll.MaNVTN),
        nv.HoTen, 'Lương tháng', 'Đầu kỳ kế toán',
        -(payroll.LuongCoBan + payroll.TienThuong)
      FROM LuongThang AS payroll
      JOIN NhanVienToaNha AS nv ON nv.MaNVTN = payroll.MaNVTN
      JOIN ToaNha AS tn ON tn.MaToaNha = nv.MaToaNha
      WHERE (@buildingId IS NULL OR nv.MaToaNha = @buildingId)
        AND (@from IS NULL OR MAKEDATE(payroll.Nam, 1) + INTERVAL (payroll.Thang - 1) MONTH >= @from)
        AND (@to IS NULL OR MAKEDATE(payroll.Nam, 1) + INTERVAL (payroll.Thang - 1) MONTH <= @to)
      ORDER BY date, type, reference`, filters);
    const rows = records.map((row) => ({ ...row, amount: amount(row.amount) }));
    const totalIncome = moneySum(rows, (row) => Math.max(0, row.amount));
    const totalExpense = moneySum(rows, (row) => Math.max(0, -row.amount));
    return summarize(rows, { totalIncome, totalExpense,
      netCashflow: Math.round((totalIncome - totalExpense) * 100) / 100,
      entryCount: rows.length }, "date");
  }
}

module.exports = { SqlStore, ValidationError, mysqlConfig, reportFilters, positional, SESSION_COLLATION };
