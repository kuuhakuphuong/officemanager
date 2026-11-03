const sql = require("mssql");
const { sqlConfig } = require("./sql-store");

const siteDefs = [
  { id: 1, building: "TN01", database: "QLToaNha_Site1" },
  { id: 2, building: "TN02", database: "QLToaNha_Site2" },
  { id: 3, building: "TN03", database: "QLToaNha_Site3" }
];

function siteConfig(site, environment = process.env) {
  const prefix = `TV7_SITE${site.id}_`;
  const config = sqlConfig({
    ...environment,
    DB_SERVER: environment[`${prefix}SERVER`] || environment.DB_SERVER,
    DB_PORT: environment[`${prefix}PORT`] || environment.DB_PORT,
    DB_DATABASE: environment[`${prefix}DATABASE`] || site.database,
    DB_USER: environment[`${prefix}USER`] || environment.DB_USER,
    DB_PASSWORD: environment[`${prefix}PASSWORD`] || environment.DB_PASSWORD,
    DB_ENCRYPT: environment[`${prefix}ENCRYPT`] || environment.DB_ENCRYPT,
    DB_TRUST_SERVER_CERTIFICATE: environment[`${prefix}TRUST_SERVER_CERTIFICATE`] || environment.DB_TRUST_SERVER_CERTIFICATE
  });
  config.options = { ...config.options, appName: "TV7 Read Only Lookup", readOnlyIntent: true, connectTimeout: 3000, requestTimeout: 10000 };
  return config;
}

async function sqlSnapshot(kind, site, environment = process.env) {
  const config = kind === "central" ? sqlConfig(environment) : siteConfig(site, environment);
  config.options = { ...config.options, appName: "TV7 Read Only Lookup", readOnlyIntent: true, connectTimeout: 3000, requestTimeout: 10000 };
  const pool = new sql.ConnectionPool(config);
  try {
    await pool.connect();
    const company = kind === "central" ? "dbo.CongTy" : "dbo.CongTy_TraCuu";
    const payroll = kind === "central" ? "dbo.LuongThang" : "dbo.LuongThang_Ky";
    const result = await pool.request().query(`
      SELECT MaToaNha AS id, TenToaNha AS name FROM dbo.ToaNha;
      SELECT MaVanPhong AS id, MaToaNha AS buildingId FROM dbo.VanPhong;
      SELECT MaHopDong AS id, MaVanPhong AS officeId FROM dbo.HopDongThue;
      SELECT MaHoaDon AS id, MaToaNha AS buildingId FROM dbo.HoaDonThang;
      SELECT usage.MaSuDung AS id, service.MaToaNha AS buildingId
        FROM dbo.ChiTietSuDungNV AS usage JOIN dbo.DichVu AS service ON service.MaDichVu = usage.MaDichVu;
      SELECT MaCongTy AS id, TenCongTy AS name, LinhVuc AS sector FROM ${company};
      SELECT MaNVTN AS employeeId, Thang AS month, Nam AS year FROM ${payroll};
    `);
    const [buildings, offices, contracts, invoices, usage, companies, payrollKeys] = result.recordsets;
    let profiles = [];
    let payrollAmounts = [];
    if (kind === "central") {
      profiles = (await pool.request().query("SELECT MaCongTy AS id, MaSoThue AS taxCode, DiaChi AS address, DienThoai AS phone, Email AS email FROM dbo.CongTy")).recordset;
      payrollAmounts = (await pool.request().query("SELECT MaNVTN AS employeeId, Thang AS month, Nam AS year, LuongCoBan AS baseSalary, TienThuong AS bonus FROM dbo.LuongThang")).recordset;
    } else if (site.id === 1) {
      profiles = (await pool.request().query("SELECT MaCongTy AS id, MaSoThue AS taxCode, DiaChi AS address, DienThoai AS phone, Email AS email FROM dbo.CongTy_HoSo")).recordset;
      payrollAmounts = (await pool.request().query("SELECT MaNVTN AS employeeId, Thang AS month, Nam AS year, LuongCoBan AS baseSalary, TienThuong AS bonus FROM dbo.LuongThang_Tien")).recordset;
    }
    return { buildings, offices, contracts, invoices, usage, companies, payrollKeys, profiles, payrollAmounts };
  } finally {
    await pool.close();
  }
}

async function mongoSnapshot(environment = process.env) {
  const { MongoClient } = require("mongodb");
  const client = new MongoClient(environment.TV7_MONGO_URI || "mongodb://127.0.0.1:27017", { serverSelectionTimeoutMS: 3000 });
  try {
    await client.connect();
    const database = client.db(environment.TV7_MONGO_DATABASE || "QuanLyToaNha");
    const names = (await database.listCollections({}, { nameOnly: true }).toArray()).map((item) => item.name);
    if (!["toanha", "hopdong_thue", "nhatky_dichvu"].every((name) => names.includes(name)))
      throw new Error("Thiếu collection TV7 trong MongoDB.");
    const [buildings, contracts, usage] = await Promise.all([
      database.collection("toanha").find({}, { projection: { _id: 0, maToaNha: 1, maSite: 1, tenToaNha: 1, vanPhong: 1 } }).toArray(),
      database.collection("hopdong_thue").find({}, { projection: { _id: 0, maToaNha: 1, vanPhongThue: 1, hoaDonThang: 1 } }).toArray(),
      database.collection("nhatky_dichvu").aggregate([{ $group: { _id: "$maToaNha", count: { $sum: 1 } } }]).toArray()
    ]);
    return { buildings: buildings.map((row) => ({ id: row.maToaNha, name: row.tenToaNha, site: row.maSite, officeIds: (row.vanPhong || []).map((office) => office.maVanPhong) })),
      contracts: contracts.map((row) => ({ buildingId: row.maToaNha,
        contractIds: (row.vanPhongThue || []).map((contract) => contract.maHopDong),
        invoiceIds: (row.hoaDonThang || []).map((invoice) => invoice.maHoaDon) })),
      usage: usage.map((row) => ({ buildingId: row._id, count: row.count })) };
  } finally {
    await client.close();
  }
}

function compareIds(actual, expected, key = (row) => row.id) {
  const left = actual.map(key).map(String);
  const right = expected.map(key).map(String);
  const leftSet = new Set(left);
  const rightSet = new Set(right);
  const onlySite = left.filter((value) => !rightSet.has(value));
  const onlyCentral = right.filter((value) => !leftSet.has(value));
  return { status: !onlySite.length && !onlyCentral.length && left.length === right.length ? "matched" : "mismatch",
    siteCount: left.length, centralCount: right.length, onlySite: onlySite.slice(0, 10), onlyCentral: onlyCentral.slice(0, 10) };
}

function payrollKey(row) { return `${row.employeeId}|${row.year}|${row.month}`; }

function reconcileSite(site, central) {
  if (!central || site.status !== "connected") return null;
  const buildingId = site.building;
  const offices = central.offices.filter((row) => row.buildingId === buildingId);
  const officeIds = new Set(offices.map((row) => row.id));
  return {
    buildings: compareIds(site.data.buildings, central.buildings.filter((row) => row.id === buildingId)),
    offices: compareIds(site.data.offices, offices),
    contracts: compareIds(site.data.contracts, central.contracts.filter((row) => officeIds.has(row.officeId))),
    invoices: compareIds(site.data.invoices, central.invoices.filter((row) => row.buildingId === buildingId)),
    usage: compareIds(site.data.usage, central.usage.filter((row) => row.buildingId === buildingId))
  };
}

function reconcile(sites, central, mongo) {
  if (!central) return null;
  const checks = {};
  if (sites.every((site) => site.status === "connected")) {
    const joined = (field) => sites.flatMap((site) => site.data[field]);
    Object.assign(checks, {
      buildings: compareIds(joined("buildings"), central.buildings),
      offices: compareIds(joined("offices"), central.offices),
      contracts: compareIds(joined("contracts"), central.contracts),
      invoices: compareIds(joined("invoices"), central.invoices),
      usage: compareIds(joined("usage"), central.usage),
      payrollKeys: compareIds(joined("payrollKeys"), central.payrollKeys, payrollKey),
      companyProfiles: compareIds(sites[0].data.profiles, central.profiles),
      payrollAmounts: compareIds(sites[0].data.payrollAmounts, central.payrollAmounts, payrollKey)
    });
    const siteCompanies = sites[0].data.companies;
    checks.companies = compareIds(siteCompanies, central.companies);
    const normalized = (row, fields) => fields.map((field) => String(row?.[field] ?? "")).join("|");
    const centralCompanies = new Map(central.companies.map((row) => [row.id, row]));
    for (const site of sites) {
      if (compareIds(site.data.companies, central.companies).status !== "matched" ||
        site.data.companies.some((row) => normalized(row, ["name", "sector"]) !== normalized(centralCompanies.get(row.id), ["name", "sector"])))
        checks.companies.status = "mismatch";
    }
    const profile = new Map(sites[0].data.profiles.map((row) => [row.id, row]));
    const centralProfile = new Map(central.profiles.map((row) => [row.id, row]));
    if (central.companies.some((row) => normalized(profile.get(row.id), ["taxCode", "address", "phone", "email"])
      !== normalized(centralProfile.get(row.id), ["taxCode", "address", "phone", "email"]))) checks.companies.status = "mismatch";
    const centralAmounts = new Map(central.payrollAmounts.map((row) => [payrollKey(row), row]));
    if (checks.payrollAmounts.status === "matched" && sites[0].data.payrollAmounts.some((row) =>
      normalized(row, ["baseSalary", "bonus"]) !== normalized(centralAmounts.get(payrollKey(row)), ["baseSalary", "bonus"]))) checks.payrollAmounts.status = "mismatch";
  }
  if (mongo) {
    checks.mongoBuildings = compareIds(mongo.buildings, central.buildings);
    checks.mongoOffices = compareIds(mongo.buildings.flatMap((row) => row.officeIds.map((id) => ({ id }))), central.offices);
    checks.mongoContracts = compareIds(mongo.contracts.flatMap((row) => row.contractIds.map((id) => ({ id }))), central.contracts);
    checks.mongoInvoices = compareIds(mongo.contracts.flatMap((row) => row.invoiceIds.map((id) => ({ id }))), central.invoices);
    const count = (rows, buildingId) => rows.filter((row) => row.buildingId === buildingId).length;
    checks.mongoUsage = { status: central.buildings.every((row) =>
      (mongo.usage.find((item) => item.buildingId === row.id)?.count || 0) === count(central.usage, row.id)) ? "matched" : "mismatch",
      siteCount: mongo.usage.reduce((sum, row) => sum + row.count, 0), centralCount: central.usage.length };
  }
  return Object.keys(checks).length ? checks : null;
}

async function getTv7Snapshot({ environment = process.env, readSql = sqlSnapshot, readMongo = mongoSnapshot } = {}) {
  const [centralResult, ...siteResults] = await Promise.allSettled([
    readSql("central", null, environment), ...siteDefs.map((site) => readSql("site", site, environment))
  ]);
  const central = centralResult.status === "fulfilled" ? centralResult.value : null;
  const sites = siteDefs.map((site, index) => {
    const result = siteResults[index];
    if (result.status !== "fulfilled") return { id: site.id, building: site.building, database: environment[`TV7_SITE${site.id}_DATABASE`] || site.database, status: "unavailable" };
    const data = result.value;
    return { id: site.id, building: site.building, database: environment[`TV7_SITE${site.id}_DATABASE`] || site.database,
      status: "connected", buildings: data.buildings, officeIds: data.offices.map((row) => row.id),
      data: { buildings: data.buildings, offices: data.offices, contracts: data.contracts,
        invoices: data.invoices, usage: data.usage, companies: data.companies,
        payrollKeys: data.payrollKeys, profiles: data.profiles, payrollAmounts: data.payrollAmounts },
      counts: { buildings: data.buildings.length, offices: data.offices.length, contracts: data.contracts.length,
        invoices: data.invoices.length, usage: data.usage.length, payroll: data.payrollKeys.length } };
  });
  const mongoResult = await Promise.allSettled([readMongo(environment)]);
  const mongo = mongoResult[0].status === "fulfilled" ? mongoResult[0].value : null;
  return { central: { status: central ? "connected" : "unavailable", database: environment.DB_DATABASE || "QLToaNha_BCNF" },
    sites: sites.map(({ data, ...site }) => ({ ...site, checks: reconcileSite({ ...site, data }, central) })),
    mongo: mongo ? { status: "connected", database: environment.TV7_MONGO_DATABASE || "QuanLyToaNha",
      buildings: mongo.buildings, contracts: mongo.contracts, usage: mongo.usage } :
      { status: "unavailable", database: environment.TV7_MONGO_DATABASE || "QuanLyToaNha" },
    checks: reconcile(sites, central, mongo) };
}

module.exports = { getTv7Snapshot, reconcile, reconcileSite, siteConfig, sqlSnapshot, mongoSnapshot };
