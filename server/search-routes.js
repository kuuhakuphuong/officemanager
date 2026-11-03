// Route tìm kiếm và lọc cho các mục vận hành. File mới: không thay đổi route danh sách cũ.
// GET /api/search/:collection?q=...&<bộ lọc> -> danh sách đã lọc (cùng hình dạng với GET /api/:collection).
const { filterRows } = require("../assets/search");

const searchable = ["companies", "offices", "contracts", "services", "employees"];

function registerSearchRoutes(app, sqlStore, store) {
  app.get("/api/search/:collection", async (request, response, next) => {
    const { collection } = request.params;
    if (!searchable.includes(collection)) {
      return response.status(404).json({ code: "NOT_FOUND", message: "Danh mục không hỗ trợ tìm kiếm." });
    }
    try {
      const rows = await (sqlStore || store).list(collection);
      return response.json(filterRows(collection, rows, request.query));
    } catch (error) {
      return next(error);
    }
  });
}

module.exports = { registerSearchRoutes };
