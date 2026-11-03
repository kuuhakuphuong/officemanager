const test = require("node:test");
const assert = require("node:assert/strict");
const { mysqlConfig, reportFilters, ValidationError } = require("../server/sql-store");

test("MySQL configuration uses the TV3 database and rejects incomplete credentials", () => {
  const env = { DB_SERVER: "localhost", DB_DATABASE: "QLToaNha_BCNF",
    DB_USER: "reader", DB_PASSWORD: "secret", DB_PORT: "3306" };
  assert.equal(mysqlConfig(env).database, "QLToaNha_BCNF");
  assert.equal(mysqlConfig(env).port, 3306);
  assert.throws(() => mysqlConfig({ ...env, DB_DATABASE: "" }), /DB_DATABASE/);
  assert.throws(() => mysqlConfig({ ...env, DB_PORT: "0" }), /DB_PORT/);
});

test("report filters accept real BCNF codes and valid periods", () => {
  assert.deepEqual(reportFilters("daily-services", { companyId: "CT01", employeeId: "NVCT001",
    serviceType: "AN_UONG", from: "2026-08-01", to: "2026-09-30" }), {
    companyId: "CT01", buildingId: null, employeeId: "NVCT001", serviceType: "AN_UONG",
    from: "2026-08-01", to: "2026-09-30"
  });
  assert.equal(reportFilters("company-cost", { from: "2026-08" }).from, "2026-08");
  assert.equal(reportFilters("company-cost", { buildingId: "TN01" }).buildingId, "TN01");
  assert.equal(reportFilters("daily-services", { buildingId: "TN02" }).buildingId, "TN02");
  for (const query of [{ from: "2026-02-30" }, { from: "2026-09-01", to: "2026-08-01" },
    { companyId: "CT01' OR 1=1" }, { surprise: "x" }, { toString: "x" }]) {
    assert.throws(() => reportFilters("daily-services", query), ValidationError);
  }
});
