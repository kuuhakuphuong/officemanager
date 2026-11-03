# Office Building Management (Web & Database Release)

Hệ thống Quản lý chuỗi Tòa nhà văn phòng cho thuê, tích hợp toàn diện giữa ứng dụng Web Fullstack (ExpressJS + Single Page App) và Hệ quản trị Cơ sở dữ liệu chuẩn hóa 18 bảng BCNF (SQL Server 2022 + MongoDB).

---

## 1. Cấu trúc thư mục dự án

Toàn bộ tài nguyên phục vụ chạy Web và Cơ sở dữ liệu đã được tinh gọn và chuẩn hóa vào thư mục này:

```text
OfficeBuilding_Web_DB/
├── assets/                     # Giao diện Web SPA (TV6 - Vũ Thành Phong)
├── database/                   # Toàn bộ mã nguồn CSDL đã được gắn tên từng thành viên
│   ├── schema/                 # DDL 18 bảng BCNF, Seed 2 tháng (TV3 - Nguyễn Thị Lan Anh)
│   │   ├── 01_CreateSchema_TV3_NguyenThiLanAnh.sql
│   │   ├── 02_InsertSeedData_TV3_NguyenThiLanAnh.sql
│   │   ├── 03_Validate_TV3_NguyenThiLanAnh.sql
│   │   └── 06_ThongNhatQuyTac_TV3_NguyenThiLanAnh.sql
│   ├── triggers/               # 6 Triggers T-SQL nghiệp vụ & test (TV5 - Khúc Tuấn Anh)
│   │   ├── 05_Phan5_Triggers_TV5_KhucTuanAnh.sql
│   │   └── 05_Phan5_KiemThu_TV5_KhucTuanAnh.sql
│   ├── transactions/           # 5 Stored Procedures ACID & Type (TV4 - Vũ Trung Hiếu)
│   │   ├── 00_TaoKieuDuLieu_TV4_VuTrungHieu.sql
│   │   ├── 02_KiemTraTuongThich_TV4_VuTrungHieu.sql
│   │   ├── 03_Transactions_TV4_VuTrungHieu.sql
│   │   ├── 04_KiemThu_TV4_VuTrungHieu.sql
│   │   ├── 05_KiemThu_DongThoi_TV4_VuTrungHieu.sql
│   │   ├── 06_DoiChieuSeed_TV4_VuTrungHieu.sql
│   │   └── ChayKiemThu_TV4_VuTrungHieu.ps1
│   ├── distributed/            # CSDL Phân tán 3 Site độc lập (TV7 - Bùi Đoàn Quang Huy)
│   │   ├── 01_NapDB_Site1_TrungTam_TV7_BuiDoanQuangHuy.sql
│   │   ├── 02_NapDB_Site2_ChiNhanh2_TV7_BuiDoanQuangHuy.sql
│   │   ├── 03_NapDB_Site3_ChiNhanh3_TV7_BuiDoanQuangHuy.sql
│   │   └── 04_TruyVan_PhanManh_TaiThiet_TV7_BuiDoanQuangHuy.sql
│   └── nosql/                  # CSDL NoSQL MongoDB & Aggregation (TV7 - Bùi Đoàn Quang Huy)
│       ├── 05_DuLieu_MongoDB_TV7_BuiDoanQuangHuy.json
│       └── 06_MongoDB_TV7_BuiDoanQuangHuy.js
├── docker/                     # Tự động hóa Docker Linux (TV6 - Vũ Thành Phong)
│   ├── init-db.sh              # Script nạp tự động SQL Server (chuẩn LF Linux)
│   └── init-mongo.js           # Script nạp tự động MongoDB
├── server/                     # Backend ExpressJS, Data Store, API (TV6 - Vũ Thành Phong)
├── test/                       # Bộ kiểm thử tự động 16 test cases
├── Dockerfile                  # Đóng gói Web App (Node 22 Alpine)
├── docker-compose.yml          # Cấu hình cụm dịch vụ Web + SQL Server + MongoDB
├── .dockerignore               # Bỏ qua node_modules, log, file thừa khi build
├── .gitignore                  # Bỏ qua dependencies, file môi trường bảo mật
├── .env.example                # Mẫu cấu hình môi trường
├── .env.docker                 # Mẫu cấu hình môi trường cho Docker
├── DOCKER_GUIDE.md             # Hướng dẫn chi tiết triển khai trên Linux
├── index.html                  # Giao diện chính của ứng dụng
├── package.json
└── README.md
```

---

## 2. Bảng phân công vai trò & File phụ trách của từng Thành viên

| Thành viên | Vai trò nghiệp vụ | Tệp mã nguồn phụ trách trực tiếp |
| :--- | :--- | :--- |
| **TV1: Lưu Văn Phương** | BA & Phân tích yêu cầu, Mô hình ERD | Đặc tả nghiệp vụ gốc, quy tắc mô hình 18 bảng BCNF |
| **TV2: Phạm Văn Lân** | Chuẩn hóa BCNF & Phụ thuộc hàm | Chứng minh toán học BCNF, thuật toán bao đóng, tách bảng `ChiTietHoaDon` |
| **TV3: Nguyễn Thị Lan Anh** | DBA / DDL & Dữ liệu lớn Seed 2 tháng | `database/schema/01_CreateSchema_TV3_NguyenThiLanAnh.sql`<br>`database/schema/02_InsertSeedData_TV3_NguyenThiLanAnh.sql`<br>`database/schema/03_Validate_TV3_NguyenThiLanAnh.sql`<br>`database/schema/06_ThongNhatQuyTac_TV3_NguyenThiLanAnh.sql` |
| **TV4: Vũ Trung Hiếu** | Senior Transactions ACID & SP | `database/transactions/00_TaoKieuDuLieu_TV4_VuTrungHieu.sql`<br>`database/transactions/02_KiemTraTuongThich_TV4_VuTrungHieu.sql`<br>`database/transactions/03_Transactions_TV4_VuTrungHieu.sql`<br>`database/transactions/04_KiemThu_TV4_VuTrungHieu.sql`<br>`database/transactions/05_KiemThu_DongThoi_TV4_VuTrungHieu.sql`<br>`database/transactions/06_DoiChieuSeed_TV4_VuTrungHieu.sql`<br>`database/transactions/ChayKiemThu_TV4_VuTrungHieu.ps1` |
| **TV5: Khúc Tuấn Anh** | Triggers T-SQL & Ràng buộc toàn vẹn | `database/triggers/05_Phan5_Triggers_TV5_KhucTuanAnh.sql`<br>`database/triggers/05_Phan5_KiemThu_TV5_KhucTuanAnh.sql` |
| **TV6: Vũ Thành Phong** | Web Fullstack, API & Tự động hóa Docker | `server/` (Backend ExpressJS, SQL Store, Transactions)<br>`assets/` (Web SPA Dashboard & CRUD)<br>`Dockerfile`, `docker-compose.yml`, `docker/init-db.sh`, `docker/init-mongo.js`<br>`test/` (Bộ kiểm thử tự động 16 test cases) |
| **TV7: Bùi Đoàn Quang Huy** | CSDL Phân tán 3 Site & NoSQL MongoDB | `database/distributed/01_NapDB_Site1_TrungTam_TV7_BuiDoanQuangHuy.sql`<br>`database/distributed/02_NapDB_Site2_ChiNhanh2_TV7_BuiDoanQuangHuy.sql`<br>`database/distributed/03_NapDB_Site3_ChiNhanh3_TV7_BuiDoanQuangHuy.sql`<br>`database/distributed/04_TruyVan_PhanManh_TaiThiet_TV7_BuiDoanQuangHuy.sql`<br>`database/nosql/05_DuLieu_MongoDB_TV7_BuiDoanQuangHuy.json`<br>`database/nosql/06_MongoDB_TV7_BuiDoanQuangHuy.js` |

---

## 3. Các phương thức triển khai & Khởi chạy

### Cách 1: Triển khai bằng Docker Compose (Khuyến nghị trên Linux/Server)

Chỉ với 1 lệnh duy nhất, toàn bộ hệ thống gồm SQL Server (tự động nạp CSDL), MongoDB và Web App sẽ khởi chạy:

```bash
# 1. Cấp quyền thực thi script init CSDL
chmod +x docker/init-db.sh

# 2. (Tùy chọn) Cấu hình mật khẩu SA / Port
cp .env.docker .env

# 3. Khởi chạy toàn bộ hệ thống ngầm
docker compose up -d --build
```

- Mở trình duyệt: `http://<IP_HOST>:3000`
- Kiểm tra kết nối CSDL: `http://<IP_HOST>:3000/api/health`
- Xem hướng dẫn chi tiết tại [DOCKER_GUIDE.md](DOCKER_GUIDE.md).

---

### Cách 2: Chạy cục bộ bằng Node.js (Chế độ Local Mock)

Không cần cài đặt SQL Server, dữ liệu sẽ được lưu tự động dạng JSON:

```bash
npm install
npm start
```
Mở trình duyệt: `http://localhost:3000`.

---

### Cách 3: Chạy cục bộ bằng Node.js kết nối SQL Server

1. Nạp các file SQL trong thư mục `database/` theo thứ tự:
   - `database/schema/01_CreateSchema_TV3_NguyenThiLanAnh.sql`
   - `database/schema/02_InsertSeedData_TV3_NguyenThiLanAnh.sql`
   - `database/triggers/05_Phan5_Triggers_TV5_KhucTuanAnh.sql`
   - `database/transactions/00_TaoKieuDuLieu_TV4_VuTrungHieu.sql`
   - `database/transactions/03_Transactions_TV4_VuTrungHieu.sql`
2. Tạo file `.env` từ `.env.example`, đặt `DATA_MODE=sqlserver` và điền thông tin kết nối SQL Server.
3. Chạy ứng dụng:
   ```bash
   npm install
   npm start
   ```

---

## 4. Kiểm tra chất lượng mã nguồn (Code Quality & Testing)

```bash
# Kiểm tra cú pháp toàn bộ file JavaScript
npm run check

# Chạy bộ test tự động
npm test
```

---

## 5. Hướng dẫn Push lên GitHub mới

Để đưa toàn bộ thư mục sạch này lên một repository mới trên GitHub:

```bash
# 1. Di chuyển vào thư mục OfficeBuilding_Web_DB
cd OfficeBuilding_Web_DB

# 2. Khởi tạo Git repository
git init

# 3. Thêm toàn bộ các file
git add .

# 4. Commit lần đầu
git commit -m "feat: initial release for Office Building Management Web & DB"

# 5. Đổi tên nhánh sang main
git branch -M main

# 6. Gắn liên kết tới repository GitHub mới của bạn
git remote add origin https://github.com/<USERNAME>/<TEN_REPO_MOI>.git

# 7. Push lên GitHub
git push -u origin main
```
