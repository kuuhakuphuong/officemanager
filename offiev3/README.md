# Quản lý Chuỗi Tòa nhà Văn phòng (officev3 - MongoDB phân mảnh)

Ứng dụng web Node.js/Express + SPA. Dữ liệu lưu trên **cụm MongoDB sharded** (config server, 3 shard, mongos), phân mảnh theo tòa nhà.

- Thiết kế và lý do: [docs/THIET_KE_MONGODB.md](docs/THIET_KE_MONGODB.md)
- Kết nối bằng MongoDB Compass: [MONGO_COMPASS.md](MONGO_COMPASS.md)
- Hướng dẫn Docker: [DOCKER_GUIDE.md](DOCKER_GUIDE.md)

## Chạy nhanh

```bash
cp .env.docker .env           # đổi MONGO_ROOT_PASSWORD
docker compose up -d --build
```

- Giao diện: `http://localhost:3000`
- Trạng thái cụm: `http://localhost:3000/api/cluster/status`
- Sức khỏe: `http://localhost:3000/api/health` (`dataMode: mongo`)

Chạy không Docker với chế độ `local` (dữ liệu JSON): `cp .env.example .env && npm install && npm start`.

## Cấu trúc

```text
assets/                  Giao diện SPA (giữ nguyên từ officev2, đổi nhãn MongoDB)
server/
  index.js               REST API (chọn kho theo DATA_MODE: local | mongo)
  local-store.js         Kho JSON cục bộ (giữ nguyên)
  crud-schema.js         Kiểm tra bản ghi CRUD (giữ nguyên)
  validation.js          Kiểm tra đầu vào giao dịch TV4 (giữ nguyên quy tắc)
  errors.js              Lỗi nghiệp vụ (mã 51xxx/55xxx giữ nguyên)
  mongo/
    connection.js        Kết nối tới mongos
    collections.js       Định nghĩa 10 collection, khóa phân mảnh
    billing.js           Công thức tiền (thuần, dùng chung giao dịch và seed)
    transactions.js      5 giao dịch TV4 trong multi-document transaction
    store.js             CRUD, tra cứu, báo cáo (aggregation), trạng thái cụm
database/seed/seed.js    Sinh và nạp dữ liệu mẫu (thiết kế riêng cho MongoDB)
docker/mongo-node.sh     Khởi tạo config server, shard, mongos (sharding, zone, user)
docs/                    Thiết kế MongoDB
test/                    Unit test (billing, validation) và test tích hợp MongoDB
```

## Kiểm thử

```bash
npm run check                                  # kiểm tra cú pháp
npm test                                       # unit test (không cần CSDL)
RUN_MONGO_TESTS=1 MONGO_URI=mongodb://admin:...@127.0.0.1:27017/?authSource=admin \
  node --test test/mongo-integration.test.js   # nạp seed vào CSDL tạm, chạy giao dịch và báo cáo
```

## Giữ nguyên và viết lại so với officev2

- Giữ nguyên: giao diện, REST API, kiểm tra đầu vào, `local-store`, cấu trúc Docker và keyfile của cụm.
- Viết lại: tầng dữ liệu (`server/mongo/`), giao dịch TV4, trigger TV5 (thành kiểm tra trong code), seed, khởi tạo cụm.
- Bỏ: toàn bộ SQL, CSDL MySQL và các trang đối soát site của bản cũ.
