const test = require("node:test");
const assert = require("node:assert/strict");
const { tv5Error } = require("../server/tv5-errors");
const { validateRecord } = require("../server/crud-schema");

test("every TV5 trigger error has a specific user message and stable code", () => {
  for (const number of [55101, 55201, 55301, 55302, 55303, 55304, 55305, 55401, 55402]) {
    const result = tv5Error({ number, message: "Internal SQL trigger text" });
    assert.equal(result.code, String(number));
    assert.ok(result.message.length > 20);
    assert.doesNotMatch(result.message, /Internal SQL|TV5-5\./);
  }
  assert.equal(tv5Error({ errno: 55303 }).code, "55303");
  assert.equal(tv5Error({ number: 51001 }), null);
  assert.equal(tv5Error({ number: 547 }), null);
  assert.equal(tv5Error({ number: 55999 }).code, "55999");
});

test("office status is read-only in CRUD payload", () => {
  const office = { code: "VP_TEST", buildingId: "TN_TEST", locationId: "VT_TEST", floor: 1, area: 80 };
  assert.deepEqual(validateRecord("offices", office).code, office.code);
  assert.throws(() => validateRecord("offices", { ...office, status: "DANG_THUE" }), /trường không hợp lệ/);
});
