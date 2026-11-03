# Hướng dẫn triển khai Docker Compose trên Linux Server

Tài liệu hướng dẫn triển khai toàn bộ hệ thống Quản lý chuỗi Tòa nhà văn phòng (`OfficeBuildingManagement`) trên máy chủ Linux bằng Docker & Docker Compose.

---

## 1. Kiến trúc dịch vụ (Services Architecture)

Hệ thống bao gồm 4 container phối hợp nhịp nhàng:
1. **`db` (Microsoft SQL Server 2022 Linux)**: Chứa Database trung tâm chuẩn 18 bảng BCNF (`QLToaNha_BCNF`) cùng 3 cơ sở dữ liệu phân tán TV7 (`QLToaNha_Site1`, `QLToaNha_Site2`, `QLToaNha_Site3`).
2. **`db-init` (Database Migration & Seed Automation)**: Container tạm thời, tự động đợi `db` sẵn sàng và nạp tuần tự:
   - DDL 18 bảng BCNF (`01_CreateSchema.sql`)
   - Dữ liệu mẫu 2 tháng (`02_InsertSeedData.sql`)
   - Ràng buộc & Kiểm chứng (`03_Validate.sql`)
   - 6 Trigger nghiệp vụ TV5 (`05_Phan5_Triggers.sql`)
   - Kiểu dữ liệu bảng TV4 (`00_TaoKieuDuLieu.sql`)
   - 5 Stored Procedures Transactions TV4 (`03_Transactions.sql`)
   - 3 CSDL phân tán TV7 (`01`, `02`, `03` Nạp DB Site 1, 2, 3)
   *(Script có tính năng Idempotent: Nếu CSDL đã tồn tại trên volume, script sẽ tự động bỏ qua để tránh trùng lặp dữ liệu)*.
3. **`mongo` (MongoDB 7.0 NoSQL)**: Chứa CSDL NoSQL `QuanLyToaNha` với các collection `toanha`, `hopdong_thue`, `nhatky_dichvu` được tự động nạp từ `06_MongoDB.js`.
4. **`web` (Node.js 22 ExpressJS & Web SPA)**: Ứng dụng Web quản lý chạy ở chế độ `DATA_MODE=sqlserver`, kết nối trực tiếp đến SQL Server và MongoDB.

---

## 2. Yêu cầu trên máy chủ Linux

- **Hệ điều hành:** Ubuntu 20.04/22.04/24.04 LTS, Debian 11/12, hoặc RHEL/CentOS/AlmaLinux.
- **Phần cứng khuyến nghị:**
  - RAM: Tối thiểu **3 GB RAM** (Do SQL Server yêu cầu tối thiểu 2 GB RAM).
  - Ổ đĩa: Còn trống tối thiểu 5 GB.
- **Công cụ đã cài đặt:**
  - Docker Engine (`>= 24.0`)
  - Docker Compose v2 (`docker compose`)

> [!TIP]
> **Cài đặt nhanh Docker & Docker Compose trên Ubuntu/Debian (nếu chưa có):**
> ```bash
> curl -fsSL https://get.docker.com -o get-docker.sh
> sudo sh get-docker.sh
> sudo usermod -aG docker $USER
> # Đăng xuất và đăng nhập lại để nhận quyền docker
> ```

---

## 3. Các bước triển khai

### Bước 1: Tải mã nguồn về máy chủ Linux

```bash
git clone https://github.com/VUTHANHPHONGs/OfficeBuildingManagement.git
cd OfficeBuildingManagement
```

### Bước 2: Cấu hình biến môi trường (Tùy chọn)

Sao chép file mẫu `.env.docker` thành `.env`:
```bash
cp .env.docker .env
```
Bạn có thể chỉnh sửa mật khẩu SA hoặc cổng port trong file `.env`:
```env
PORT=3000
MSSQL_SA_PASSWORD=YourStrong@Passw0rd!
DB_PORT=1433
```
*(Nếu không tạo file `.env`, Docker Compose sẽ sử dụng mật khẩu mặc định đã khai báo sẵn)*.

### Bước 3: Phân quyền thực thi cho script khởi tạo DB

```bash
chmod +x docker/init-db.sh
```

### Bước 4: Khởi chạy toàn bộ hệ thống

Chạy lệnh sau để build image Web và khởi động toàn bộ cụm dịch vụ:

```bash
docker compose up -d --build
```

---

## 4. Kiểm tra trạng thái và theo dõi Logs

### Xem trạng thái các container:
```bash
docker compose ps
```
*Kết quả mẫu:*
- `office_sqlserver` (db): `Up (healthy)`
- `office_db_init`: `Exited (0)` (Đã hoàn tất nạp DDL & Seed)
- `office_mongodb` (mongo): `Up`
- `office_web_app` (web): `Up`

### Theo dõi log khởi tạo database:
```bash
docker compose logs -f db-init
```

### Theo dõi log của ứng dụng web:
```bash
docker compose logs -f web
```

---

## 5. Truy cập ứng dụng

Mở trình duyệt và truy cập vào IP của máy chủ Linux:
```
http://<IP_MAY_CHU_LINUX>:3000
```
Ví dụ: `http://192.168.1.100:3000` hoặc `http://your-server-ip:3000`.

- Kiểm tra tình trạng kết nối CSDL tại API:  
  `http://<IP_MAY_CHU_LINUX>:3000/api/health`  
  *(Sẽ trả về `status: "ok"`, `schema: "TV3-BCNF-18"`, `transactionsReady: true`, `paymentReady: true`)*.

---

## 6. Các lệnh quản lý thông dụng

- **Dừng hệ thống:**
  ```bash
  docker compose down
  ```
- **Khởi động lại hệ thống:**
  ```bash
  docker compose restart
  ```
- **Xem log tổng hợp tất cả dịch vụ:**
  ```bash
  docker compose logs -f
  ```
- **Xóa toàn bộ dữ liệu CSDL để làm mới (Reset dữ liệu sạch):**
  ```bash
  docker compose down -v
  docker compose up -d
  ```
