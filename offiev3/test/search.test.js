const test = require("node:test");
const assert = require("node:assert/strict");
const { filterRows, norm } = require("../assets/search");

const companies = [
  { id: "CT01", name: "Công ty TNHH Giải pháp Phần mềm Thăng Long", taxCode: "0101234501", sector: "Công nghệ thông tin" },
  { id: "CT02", name: "Công ty Cổ phần Thương mại Hoàng Hà", taxCode: "0101234502", sector: "Thương mại" }
];

test("search ignores case and Vietnamese diacritics", () => {
  assert.equal(norm("Thăng Long"), "thang long");
  assert.deepEqual(filterRows("companies", companies, { q: "thang long" }).map((r) => r.id), ["CT01"]);
  assert.deepEqual(filterRows("companies", companies, { q: "HOÀNG HÀ" }).map((r) => r.id), ["CT02"]);
});

test("exact filters combine with the keyword", () => {
  assert.equal(filterRows("companies", companies, { sector: "Thương mại" }).length, 1);
  assert.equal(filterRows("companies", companies, { q: "công ty", sector: "Thương mại" })[0].id, "CT02");
  assert.equal(filterRows("companies", companies, { q: "không có" }).length, 0);
  assert.equal(filterRows("companies", companies, { sector: "" }).length, 2);
});

test("contract active filter follows the start and end dates", () => {
  const contracts = [
    { id: "A", startDate: "2020-01-01", endDate: "2099-12-31" },
    { id: "B", startDate: "2020-01-01", endDate: "2020-06-30" }
  ];
  assert.deepEqual(filterRows("contracts", contracts, { active: "1" }).map((r) => r.id), ["A"]);
  assert.deepEqual(filterRows("contracts", contracts, { active: "0" }).map((r) => r.id), ["B"]);
  assert.equal(filterRows("contracts", contracts, {}).length, 2);
});

test("employee type and company filters", () => {
  const staff = [
    { id: "CT:NVCT001", type: "company", companyId: "CT01", name: "Trần Đức Khoa", email: "a@x.vn" },
    { id: "TN:QL01", type: "building", companyId: null, name: "Nguyễn Hoàng Long", email: "b@x.vn" }
  ];
  assert.deepEqual(filterRows("employees", staff, { type: "building" }).map((r) => r.id), ["TN:QL01"]);
  assert.deepEqual(filterRows("employees", staff, { q: "khoa" }).map((r) => r.id), ["CT:NVCT001"]);
  assert.deepEqual(filterRows("employees", staff, { companyId: "CT01" }).map((r) => r.id), ["CT:NVCT001"]);
});
