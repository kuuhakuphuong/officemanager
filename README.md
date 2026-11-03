# Office Building Management (Web & Database Release)

Hệ thống Quản lý chuỗi Tòa nhà văn phòng cho thuê, tích hợp toàn diện giữa ứng dụng Web Fullstack (ExpressJS + Single Page App) và Hệ quản trị Cơ sở dữ liệu chuẩn hóa 18 bảng BCNF (SQL Server 2022 + MongoDB).

---

## 1. Cấu trúc thư mục dự án

Toàn bộ tài nguyên phục vụ chạy Web và Cơ sở dữ liệu đã được tinh gọn và chuẩn hóa vào thư mục này:

```text
OfficeBuilding_Web_DB/
├── assets/                     # Giao diện Web SPA (JavaScript, CSS)
├── database/                   # Toàn bộ mã nguồn CSDL đã được phân loại chuẩn hóa
│   ├── schema/                 # DDL 18 bảng BCNF, Dữ liệu mẫu (Seed) và Validate
│   │   ├── 01_CreateSchema.sql
│   │   ├── 02_InsertSeedData.sql
│   │   ├── 03_Validate.sql
│   │   └── 06_ThongNhatQuyTac.sql
│   ├── triggers/               # 6 Triggers T-SQL nghiệp vụ và kịch bản kiểm thử
│   │   ├── 05_Phan5_Triggers.sql
│   │   └── 05_Phan5_KiemThu.sql
│   ├── transactions/           # 5 Stored Procedures ACID, Table Types và Runner
│   │   ├── 00_TaoKieuDuLieu.sql
│   │   ├── 02_KiemTraTuongThich.sql
│   │   ├── 03_Transactions.sql
│   │   ├── 04_KiemThu.sql
│   │   ├── 05_KiemThu_DongThoi.sql
│   │   ├── 06_DoiChieuSeed.sql
│   │   └── ChayKiemThu.ps1
│   ├── distributed/            # Kịch bản CSDL Phân tán 3 Site độc lập
│   │   ├── 01_NapDB_Site1_TrungTam.sql
│   │   ├── 02_NapDB_Site2_ChiNhanh2.sql
│   │   ├── 03_NapDB_Site3_ChiNhanh3.sql
│   │   └── 04_TruyVan_PhanManh_TaiThiet.sql
│   └── nosql/                  # CSDL NoSQL MongoDB và kịch bản Aggregation
│       ├── 05_DuLieu_MongoDB.json
│       └── 06_MongoDB.js
├── docker/                     # Script tự động hóa khởi tạo CSDL trong container
│   ├── init-db.sh              # Script nạp tự động SQL Server (chuẩn LF Linux)
│   └── init-mongo.js           # Script nạp tự động MongoDB
├── server/                     # Backend ExpressJS, Data Store, API & Transaction Handlers
├── test/                       # Bộ kiểm thử tự động (Unit & Integration Tests)
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

## 2. Các phương thức triển khai & Khởi chạy

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
   - `database/schema/01_CreateSchema.sql`
   - `database/schema/02_InsertSeedData.sql`
   - `database/triggers/05_Phan5_Triggers.sql`
   - `database/transactions/00_TaoKieuDuLieu.sql`
   - `database/transactions/03_Transactions.sql`
2. Tạo file `.env` từ `.env.example`, đặt `DATA_MODE=sqlserver` và điền thông tin kết nối SQL Server.
3. Chạy ứng dụng:
   ```bash
   npm install
   npm start
   ```

---

## 3. Kiểm tra chất lượng mã nguồn (Code Quality & Testing)

```bash
# Kiểm tra cú pháp toàn bộ file JavaScript
npm run check

# Chạy bộ test tự động
npm test
```

---

## 4. Hướng dẫn khởi tạo và Push lên GitHub mới

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
