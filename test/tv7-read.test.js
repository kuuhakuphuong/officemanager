const test = require("node:test");
const assert = require("node:assert/strict");
const { getTv7Snapshot } = require("../server/tv7-read");

function siteData(id) {
  const building = `TN0${id}`;
  return {
    buildings: [{ id: building, name: `Building ${id}` }],
    offices: [{ id: `VP0${id}`, buildingId: building }],
    contracts: [{ id: `HD0${id}`, officeId: `VP0${id}` }],
    invoices: [{ id, buildingId: building }],
    usage: [{ id, buildingId: building }],
    companies: [{ id: "CT01", name: "Company", sector: "IT" }],
    payrollKeys: [{ employeeId: `NV0${id}`, month: 8, year: 2026 }],
    profiles: id === 1 ? [{ id: "CT01", taxCode: "0123456789", address: "A", phone: null, email: null }] : [],
    payrollAmounts: id === 1 ? [1, 2, 3].map((number) => ({ employeeId: `NV0${number}`, month: 8, year: 2026, baseSalary: 100, bonus: 10 })) : []
  };
}

function centralData() {
  const sites = [1, 2, 3].map(siteData);
  const merged = {};
  for (const key of ["buildings", "offices", "contracts", "invoices", "usage", "payrollKeys"]) merged[key] = sites.flatMap((site) => site[key]);
  return { ...merged, companies: sites[0].companies, profiles: sites[0].profiles, payrollAmounts: sites[0].payrollAmounts };
}

test("connected SQL and MongoDB sources return real-query reconciliation, with no private fragment rows in API", async () => {
  const snapshot = await getTv7Snapshot({
    environment: { DB_DATABASE: "QLToaNha_BCNF" },
    readSql: async (kind, site) => kind === "central" ? centralData() : siteData(site.id),
    readMongo: async () => ({
      buildings: [1, 2, 3].map((id) => ({ id: `TN0${id}`, officeIds: [`VP0${id}`] })),
      contracts: [1, 2, 3].map((id) => ({ buildingId: `TN0${id}`, contractIds: [`HD0${id}`], invoiceIds: [id] })),
      usage: [1, 2, 3].map((id) => ({ buildingId: `TN0${id}`, count: 1 }))
    })
  });
  assert.equal(snapshot.central.status, "connected");
  assert.equal(snapshot.mongo.status, "connected");
  assert.ok(snapshot.sites.every((site) => site.status === "connected"));
  assert.ok(Object.values(snapshot.checks).every((check) => check.status === "matched"));
  assert.equal(snapshot.sites[0].data, undefined);
  assert.equal(JSON.stringify(snapshot).includes("0123456789"), false);
});

test("unreachable sources report unavailable and never synthesize comparison data", async () => {
  const snapshot = await getTv7Snapshot({
    environment: {},
    readSql: async () => { throw new Error("connection refused"); },
    readMongo: async () => { throw new Error("connection refused"); }
  });
  assert.equal(snapshot.central.status, "unavailable");
  assert.ok(snapshot.sites.every((site) => site.status === "unavailable" && site.counts === undefined));
  assert.equal(snapshot.mongo.status, "unavailable");
  assert.equal(snapshot.checks, null);
});

test("a connected fragment is checked independently and a missing peer does not claim a chain match", async () => {
  const snapshot = await getTv7Snapshot({
    environment: {},
    readSql: async (kind, site) => {
      if (kind === "central") return centralData();
      if (site.id === 2) throw new Error("offline");
      const data = siteData(site.id);
      if (site.id === 3) data.offices = [];
      return data;
    },
    readMongo: async () => { throw new Error("offline"); }
  });
  assert.equal(snapshot.checks, null);
  assert.equal(snapshot.sites[0].checks.offices.status, "matched");
  assert.equal(snapshot.sites[1].checks, null);
  assert.equal(snapshot.sites[2].checks.offices.status, "mismatch");
});
