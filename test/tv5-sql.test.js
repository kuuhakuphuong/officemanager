const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const sql = require("mssql");
const { SqlStore, sqlConfig } = require("../server/sql-store");
const { tv5Error } = require("../server/tv5-errors");

const root = path.resolve(__dirname, "..");
const tv3 = path.join(root, "database", "schema");
const tv5 = path.join(root, "database", "triggers");
const enabled = process.env.RUN_SQL_TV5_TESTS === "1";

function batches(file, databaseName, skip = 0) {
  const source = fs.readFileSync(file, "utf8").replaceAll("QLToaNha_BCNF", databaseName);
  return source.split(/^\s*GO\s*$/gim).slice(skip).filter((batch) => batch.trim());
}

async function runBatches(pool, file, databaseName, skip = 0) {
  const messages = [];
  for (const batch of batches(file, databaseName, skip)) {
    const request = pool.request();
    request.on("info", (info) => messages.push(info.message));
    await request.batch(batch);
  }
  return messages;
}

test("TV5 triggers and office status on an isolated SQL Server database", { skip: !enabled }, async (t) => {
  require("dotenv").config({ path: path.join(root, ".env") });
  const name = `QLToaNha_BCNF_TV5_Test_${crypto.randomBytes(4).toString("hex")}`;
  const config = sqlConfig();
  const master = new sql.ConnectionPool({ ...config, database: "master", pool: { max: 1, min: 1 } });
  let sandbox;
  let created = false;
  try {
    await master.connect();
    await master.request().batch(`CREATE DATABASE [${name}]`);
    created = true;
    sandbox = new sql.ConnectionPool({ ...config, database: name, pool: { max: 1, min: 1 } });
    await sandbox.connect();

    await runBatches(sandbox, path.join(tv3, "01_CreateSchema_TV3_NguyenThiLanAnh.sql"), name, 3);
    await runBatches(sandbox, path.join(tv3, "02_InsertSeedData_TV3_NguyenThiLanAnh.sql"), name, 1);
    await runBatches(sandbox, path.join(tv3, "03_Validate_TV3_NguyenThiLanAnh.sql"), name, 1);
    await runBatches(sandbox, path.join(tv5, "05_Phan5_Triggers_TV5_KhucTuanAnh.sql"), name);
    const results = await runBatches(sandbox, path.join(tv5, "05_Phan5_KiemThu_TV5_KhucTuanAnh.sql"), name);
    const cases = results.filter((message) => /\b5\.[1-5]-TC\d+\s+(?:PASS|FAIL):/.test(message));
    t.diagnostic(`TV5 cases: ${cases.length}; failures: ${cases.filter((message) => /\bFAIL:/.test(message)).length}`);
    assert.ok(cases.length >= 19, "TV5 test cases did not produce the expected results");
    assert.deepEqual(cases.filter((message) => /\bFAIL:/.test(message)), []);

    for (const [statement, code] of [
      ["INSERT dbo.HopDongThue(MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc) VALUES ('TV5_CONFLICT', 'CT01', 'VP01', '2026-11-01', '2026-11-30')", "55101"],
      ["INSERT dbo.ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung) VALUES ('NVCT001', 'AN01', DATEADD(day, 30, GETDATE()), 1, 35000)", "55303"],
      ["DELETE dbo.CongTy WHERE MaCongTy = 'CT01'", "55401"]
    ]) {
      await assert.rejects(sandbox.request().query(statement),
        (error) => tv5Error(error)?.code === code, `Expected SQL error ${code}`);
    }

    const store = new SqlStore({ ...config, database: name });
    try {
      const offices = await store.list("offices");
      assert.ok(offices.length > 0);
      assert.ok(offices.every((office) => ["TRONG", "DANG_THUE"].includes(office.status)));
      await sandbox.request().query("INSERT dbo.CongTy(MaCongTy, TenCongTy, MaSoThue, DiaChi, LinhVuc) VALUES ('TV5_EMPTY', N'Test delete', '8888888888', N'Test', N'Test')");
      assert.equal(await store.remove("companies", "TV5_EMPTY"), true);
      assert.equal((await sandbox.request().query("SELECT COUNT(*) AS total FROM dbo.CongTy WHERE MaCongTy = 'TV5_EMPTY'")).recordset[0].total, 0);
      await assert.rejects(store.remove("companies", "CT01"),
        (error) => tv5Error(error)?.code === "55401");
    } finally { if (store.poolPromise) await (await store.poolPromise).close(); }

    t.diagnostic("TV3 validation passed before TV5; TV5 trigger cases and web office status passed after installation.");
  } finally {
    if (sandbox) await sandbox.close();
    if (created) {
      await master.request().batch(`ALTER DATABASE [${name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [${name}]`);
    }
    await master.close();
  }
});
