const test = require("node:test");
const assert = require("node:assert/strict");
const { validateRecord } = require("../server/crud-schema");
const { ValidationError } = require("../server/sql-store");

const company = { code: "CT_TEST", name: "Test", taxCode: "1234567890", address: "Hà Nội", sector: "Công nghệ" };
const contract = { code: "HD_TEST", companyId: "CT_TEST", officeId: "VP_TEST", startDate: "2026-11-01" };
const employee = { type: "company", code: "NV_TEST", name: "Test", gender: "O", birthDate: "2000-01-01",
  startDate: "2026-11-01", companyId: "CT_TEST", jobTitle: "Kỹ sư" };

test("only real company columns are accepted and tax code follows TV3 format", () => {
  assert.equal(validateRecord("companies", company).phone, null);
  for (const body of [{ ...company, contact: "Someone" }, { ...company, address: "" },
    { ...company, taxCode: "123456789A" }, { ...company, taxCode: "1234567890-1234" }]) {
    assert.throws(() => validateRecord("companies", body), ValidationError);
  }
});

test("contracts bind one office and allow the TV1 same-day end date", () => {
  assert.equal(validateRecord("contracts", { ...contract, endDate: contract.startDate }).endDate, contract.startDate);
  assert.throws(() => validateRecord("contracts", { ...contract, endDate: "2026-10-31" }), ValidationError);
  assert.throws(() => validateRecord("contracts", { ...contract, officeIds: ["VP1", "VP2"] }), ValidationError);
  assert.throws(() => validateRecord("contracts", { ...contract, startDate: "2026-02-30" }), ValidationError);
});

test("office floor and area and service price follow the chosen constraints", () => {
  const office = { code: "VP_TEST", buildingId: "TN1", locationId: "VT1", floor: 1, area: 50.25 };
  assert.equal(validateRecord("offices", office).area, 50.25);
  assert.throws(() => validateRecord("offices", { ...office, floor: 0 }), ValidationError);
  assert.throws(() => validateRecord("offices", { ...office, area: 0 }), ValidationError);
  const service = { code: "DV_TEST", buildingId: "TN1", serviceTypeId: "LDV1", name: "Vệ sinh", basePrice: 1 };
  assert.equal(validateRecord("services", service).basePrice, 1);
  assert.throws(() => validateRecord("services", { ...service, basePrice: 0 }), ValidationError);
  assert.throws(() => validateRecord("services", { ...service, unit: "tháng" }), ValidationError);
});

test("employee models have distinct references, M/F/O, and same-day leaving", () => {
  assert.equal(validateRecord("employees", { ...employee, endDate: employee.startDate }).gender, "O");
  for (const body of [{ ...employee, gender: "NAM" }, { ...employee, birthDate: employee.startDate },
    { ...employee, buildingId: "TN1" }, { ...employee, endDate: "2026-10-31" },
    { ...employee, type: "building", companyId: null, jobTitle: null, buildingId: "TN1", employeeType: "DICH_VU" }]) {
    assert.throws(() => validateRecord("employees", body), ValidationError);
  }
  const building = { ...employee, type: "building", companyId: null, jobTitle: null,
    buildingId: "TN1", employeeType: "DICH_VU", managerId: "QL1" };
  assert.equal(validateRecord("employees", building).managerId, "QL1");
  assert.throws(() => validateRecord("employees", { ...building, employeeType: "QUAN_LY" }), ValidationError);
});
