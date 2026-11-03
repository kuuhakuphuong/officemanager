# Hướng dẫn triển khai Docker Compose (MySQL + MongoDB + phân tán 3 site)

Tài liệu này mô tả cách chạy toàn bộ hệ thống Quản lý Tòa nhà bằng `docker compose`.

## 1. Kiến trúc triển khai

| Container | Vai trò | Cổng trên máy host |
| :--- | :--- | :--- |
| `office_mysql_central` | MySQL 8.0.40: CSDL trung tâm `QLToaNha_BCNF` (18 bảng BCNF, seed, trigger TV5, procedure TV4) + site 1 `QLToaNha_Site1` (TN01, trung tâm) | `3306` (`DB_PORT`) |
| `office_mysql_site2` | MySQL 8.0.40 riêng cho chi nhánh 2: `QLToaNha_Site2` (TN02) | `3307` (`SITE2_DB_PORT`) |
| `office_mysql_site3` | MySQL 8.0.40 riêng cho chi nhánh 3: `QLToaNha_Site3` (TN03) | `3308` (`SITE3_DB_PORT`) |
| `office_mongodb` | MongoDB 7.0 có xác thực, database `QuanLyToaNha` (3 collection: `toanha`, `hopdong_thue`, `nhatky_dichvu`) | `27017` (`MONGO_PORT`) |
| `office_db_init` | Chạy một lần rồi thoát: nạp trung tâm, lập mảnh cho 3 site, nạp MongoDB | - |
| `office_web_app` | Node.js 22 + Express + giao diện SPA | `3000` (`PORT`) |

Phân tán: mỗi site nằm trên một máy chủ MySQL riêng. Site 2 và 3 nhận mảnh ngang (toà nhà của mình, hợp đồng, nhật ký dịch vụ, hóa đơn, lịch sử lương) từ trung tâm; trung tâm giữ thêm mảnh dọc (hồ sơ thuế, toàn bộ tiền lương). Trang đối soát `/api/tv7/distribution` kiểm tra cả 3 site và MongoDB với trung tâm.

## 2. Yêu cầu

- Docker Desktop (Windows/macOS) hoặc Docker Engine + Compose v2 (Linux).
- Cổng trống: `3000`, `3306`, `3307`, `3308`, `27017`.
- Khoảng 2 GB RAM cho 4 container CSDL và web.

## 3. Cấu hình

```bash
cp .env.docker .env          # Windows PowerShell: copy .env.docker .env
```

Mở `.env` và **đổi hai mật khẩu** trước khi chạy:

- `MYSQL_ROOT_PASSWORD` - dùng chung cho 3 server MySQL và web.
- `MONGO_ROOT_PASSWORD` - mật khẩu tài khoản `admin` của MongoDB.

Compose sẽ từ chối khởi động nếu hai biến này chưa được đặt.

## 4. Chạy hệ thống

```bash
docker compose up -d --build
```

Theo dõi tiến trình nạp dữ liệu (khoảng 1-2 phút):

```bash
docker compose logs -f db-init
```

Kết thúc tốt khi log có dòng `[SUCCESS] KHOI TAO CSDL MYSQL THANH CONG (trung tam + 3 site)` và container `office_db_init` ở trạng thái `Exited (0)`.

Kiểm tra:

```bash
docker compose ps
curl http://localhost:3000/api/health          # dataMode=mysql, transactionsReady=true
curl http://localhost:3000/api/tv7/distribution  # central/sites/mongo = connected
```

Mở trình duyệt: `http://localhost:3000`.

## 5. Kết nối công cụ ngoài

**MySQL** (MySQL Workbench, DBeaver, ...): host `localhost`, user `root`, mật khẩu `MYSQL_ROOT_PASSWORD`.

| Node | Port | Database |
| :--- | :--- | :--- |
| Trung tâm | `3306` | `QLToaNha_BCNF`, `QLToaNha_Site1` |
| Site 2 | `3307` | `QLToaNha_Site2` |
| Site 3 | `3308` | `QLToaNha_Site3` |

**MongoDB**: xem hướng dẫn chi tiết trong [MONGO_COMPASS.md](MONGO_COMPASS.md).

## 6. Vận hành thường gặp

| Tình huống | Cách xử lý |
| :--- | :--- |
| Sửa dữ liệu mẫu hoặc chạy lại từ đầu | `docker compose down -v` (xóa volume) rồi `docker compose up -d --build` |
| `db-init` lỗi | `docker compose logs db-init`; sửa nguyên nhân rồi `docker compose up -d db-init` (khi QLToaNha_BCNF đã tồn tại thì bước nạp trung tâm được bỏ qua) |
| Web báo `DATABASE_UNAVAILABLE` | Kiểm tra `docker compose ps` xem `office_mysql_central` có `healthy` không |
| Đổi code web | `docker compose up -d --build web` |
| Dừng hệ thống, giữ dữ liệu | `docker compose down` |

## 7. Lưu ý bảo mật

- Cấu hình này dùng tài khoản `root` cho ứng dụng để đơn giản khi demo. Khi triển khai thật, tạo tài khoản MySQL riêng với quyền tối thiểu.
- Không mở các cổng `3306`, `3307`, `3308`, `27017` ra Internet công cộng. Chỉ publish khi cần truy cập từ máy khác trong mạng nội bộ.
- Các mật khẩu trong `.env.docker` chỉ là giá trị mẫu.
