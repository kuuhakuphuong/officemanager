# Quản lý Chuỗi Tòa nhà Văn phòng (phiên bản MySQL + MongoDB, phân tán)

Ứng dụng web (Node.js/Express + SPA) quản lý chuỗi tòa nhà cho thuê. CSDL quan hệ dùng **MySQL 8.0.40** (18 bảng BCNF, trigger TV5, procedure giao dịch TV4, 3 site phân tán); CSDL NoSQL dùng **MongoDB 7.0**.

## Chạy nhanh bằng Docker Compose (khuyến nghị)

```bash
cp .env.docker .env        # đổi MYSQL_ROOT_PASSWORD và MONGO_ROOT_PASSWORD
docker compose up -d --build
```

- Giao diện: `http://localhost:3000`
- Kiểm tra: `http://localhost:3000/api/health`, `http://localhost:3000/api/tv7/distribution`
- Chi tiết kiến trúc, cổng, xử lý sự cố: [DOCKER_GUIDE.md](DOCKER_GUIDE.md)
- Kết nối MongoDB bằng Compass: [MONGO_COMPASS.md](MONGO_COMPASS.md)
- Mô hình phân tán (phân mảnh MySQL, sharding MongoDB, lý do và cấu hình): [docs/MO_HINH_PHAN_TAN.md](docs/MO_HINH_PHAN_TAN.md)

## Chạy cục bộ (không Docker)

Chế độ `local` lưu dữ liệu JSON trên máy, không cần CSDL:

```bash
cp .env.example .env       # DATA_MODE=local
npm install
npm start                  # http://localhost:3000
```

Chế độ `mysql` cần MySQL 8.0.16 trở lên: nạp `database/schema/01..03`, `database/triggers/05_*`, `database/transactions/00,02,03` vào database `QLToaNha_BCNF`, rồi đặt `DATA_MODE=mysql` trong `.env`.

## Cấu trúc thư mục

```text
assets/                 Giao diện SPA
server/                 Express API, sql-store (MySQL), transactions (TV4), tv7-read (đối soát phân tán + MongoDB)
database/
  schema/               01 DDL 18 bảng, 02 seed 2 tháng, 03 kiểm chứng (cấu trúc, đối soát, 32 ca vi phạm rằng buộc)
  triggers/             05 trigger TV5 (10 trigger vật lý)
  transactions/         00/02 kiểm tra; 03 năm procedure giao dịch TV4 (tham số JSON, GET_LOCK)
  distributed/          01 template tạo mảnh site (dùng cho site 1, 2, 3); 02 mảnh riêng của trung tâm
  nosql/                06 script MongoDB gốc, 05 dữ liệu JSON mẫu
  tools/                mysql-script.js: tách file .sql (có DELIMITER) để chạy qua mysql2
docker/                 init-db.sh (nạp MySQL trung tâm + site), init-mongo.js (nạp MongoDB)
test/                   Unit test + mysql-integration.test.js (cần MySQL thật)
```

## Kiểm thử

```bash
npm run check              # kiểm tra cú pháp
npm test                   # unit test (không cần CSDL)
RUN_MYSQL_TESTS=1 DB_SERVER=localhost DB_PORT=3306 DB_USER=root DB_PASSWORD=... DB_DATABASE=QLToaNha_BCNF \
  node --test test/mysql-integration.test.js   # tạo CSDL tạm, nạp schema/trigger/TV4, kiểm tra luồng chính
```

## Ghi chú chuyển đổi từ SQL Server

- Các phần T-SQL (kiểm thử chi tiết TV4 đồng thời, kiểm thử trigger TV5 và script chạy `sqlcmd`/PowerShell) chưa được chuyển sang MySQL trong bản này; bản gốc vẫn nằm ở thư mục dự án cha.
- Trigger và procedure MySQL không có `PRINT`; thông tin bậc giá và thống kê được bỏ khỏi thông báo của trigger.
- Hai bậc giá trong `TR_DangKyDichVu_ApDungBacThang` và tổng hợp thống kê trong trigger 5.5 vẫn được tính trong procedure giao dịch TV4, không còn in ra màn hình.
