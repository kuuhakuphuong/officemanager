# Hướng dẫn Docker Compose (officev3)

## Kiến trúc

| Container | Vai trò | Cổng host |
| :--- | :--- | :--- |
| `office_mongo_keygen` | Sinh keyfile xác thực nội bộ (chạy một lần) | - |
| `office_mongo_config` | Config server (replica set `cfgRS`) | - |
| `office_mongo_shard1..3` | Shard 1 = TN01, shard 2 = TN02, shard 3 = TN03 | - |
| `office_mongos` | Router: ứng dụng và Compass kết nối vào đây | `27017` (`MONGO_PORT`) |
| `office_db_init` | Nạp dữ liệu mẫu (`seed.js`) rồi thoát | - |
| `office_web_app` | Web (Node.js 22) | `3000` (`PORT`) |

## Chạy

```bash
cp .env.docker .env
# đổi MONGO_ROOT_PASSWORD trong .env
docker compose up -d --build
docker compose logs -f db-init     # chờ dòng "[OK] Đã nạp dữ liệu MongoDB"
docker compose ps
```

Khi `office_db_init` thoát với mã 0 và `office_mongos` ở trạng thái `healthy`, hệ thống đã sẵn sàng.

## Xử lý sự cố

| Tình huống | Cách xử lý |
| :--- | :--- |
| Chạy lại từ đầu, xóa dữ liệu | `docker compose down -v --remove-orphans` rồi `docker compose up -d --build` |
| `db-init` lỗi | `docker compose logs db-init`; sửa rồi `docker compose up -d db-init` (seed xóa dữ liệu cũ và nạp lại) |
| `mongos` không healthy | `docker compose logs mongos`: tìm `[ERROR]` |
| Đổi code web | `docker compose up -d --build web` |
| Trùng cổng với stack khác | Dừng stack kia (`docker compose down` trong thư mục đó) hoặc đổi `MONGO_PORT`/`PORT` |

## Lưu ý

- Cấu hình demo: một config server và một node mỗi shard. Môi trường thật cần replica set đầy đủ.
- Không mở cổng `27017` ra Internet. Chưa bật TLS.
- Mật khẩu trong `.env.docker` chỉ là giá trị mẫu.
