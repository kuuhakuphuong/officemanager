const test = require("node:test");
const assert = require("node:assert/strict");
const { validateTransaction, tv4Error, paymentMessage } = require("../server/transactions");
const { ValidationError } = require("../server/sql-store");

test("TV4 request validation protects batch keys, dates and period values", () => {
  assert.deepEqual(validateTransaction("contract", { companyId: "CT01", buildingId: "TN01",
    startDate: "2028-01-01", endDate: "", officeIds: ["VP01", "VP02"] }).officeIds, ["VP01", "VP02"]);
  for (const body of [
    { companyId: "CT01", buildingId: "TN01", startDate: "2028-01-01", officeIds: [] },
    { companyId: "CT01", buildingId: "TN01", startDate: "2028-01-01", officeIds: ["VP01", "VP01"] },
    { companyId: "CT01' OR 1=1", buildingId: "TN01", startDate: "2028-01-01", officeIds: ["VP01"] },
    { companyId: "CT01", buildingId: "TN01", startDate: "2028-02-30", officeIds: ["VP01"] },
    { companyId: "CT01", buildingId: "TN01", startDate: "0000-01-01", officeIds: ["VP01"] },
    // TV6 sửa: chỉ ngày kết thúc trước ngày bắt đầu mới sai.
    { companyId: "CT01", buildingId: "TN01", startDate: "2028-01-02", endDate: "2028-01-01", officeIds: ["VP01"] }
  ]) assert.throws(() => validateTransaction("contract", body), ValidationError);
  assert.equal(validateTransaction("contract", { companyId: "CT01", buildingId: "TN01",
    startDate: "2028-01-01", endDate: "2028-01-01", officeIds: ["VP01"] }).endDate, "2028-01-01");
  assert.throws(() => validateTransaction("daily-service", { items: [
    { employeeId: "NV1", serviceId: "DV1", useDate: "2026-08-01", quantity: 1 },
    { employeeId: "NV1", serviceId: "DV1", useDate: "2026-08-01", quantity: 2 }
  ] }), ValidationError);
  assert.throws(() => validateTransaction("invoice", { buildingId: "TN01", month: 13, year: 2026 }), ValidationError);
  assert.throws(() => validateTransaction("payroll", { buildingId: "TN01", month: "8", year: 2026 }), ValidationError);
});

test("TV4 errors retain procedure codes and payment validates full-payment request", () => {
  // TV6 sửa: 51400 chỉ dành cho bản procedure cũ; thanh toán hợp lệ được chuyển tới SQL.
  assert.deepEqual(tv4Error({ number: 51400 }), { code: "51400", message: paymentMessage });
  assert.equal(tv4Error({ number: 51406 }).code, "51406");
  assert.equal(tv4Error({ originalError: { info: { number: 51106 } } }).code, "51106");
  assert.equal(tv4Error({ number: 55101 }), null);
  const payment = { invoiceId: 5, amount: 12345.67, paymentDate: "2026-11-01", collector: " Người thu " };
  assert.deepEqual(validateTransaction("payment", payment), { ...payment, collector: "Người thu" });
  for (const invalid of [{ ...payment, invoiceId: 0 }, { ...payment, amount: 0 },
    { ...payment, amount: 1.001 }, { ...payment, paymentDate: "2026-02-30" },
    { ...payment, collector: " " }, { ...payment, unknown: true }])
    assert.throws(() => validateTransaction("payment", invalid), ValidationError);
});
