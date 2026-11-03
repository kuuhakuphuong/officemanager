# Kết nối MongoDB bằng MongoDB Compass

Hướng dẫn kết nối từ máy bạn (Windows/macOS/Linux) vào MongoDB chạy trong Docker Compose.

Compass kết nối vào **mongos** (router của cụm sharded, cổng 27017). Không kết nối trực tiếp vào từng shard. Chi tiết cụm xem [docs/MO_HINH_PHAN_TAN.md](docs/MO_HINH_PHAN_TAN.md).

## 1. Thông tin kết nối

| Mục | Giá trị mặc định (xem `.env`) |
| :--- | :--- |
| Máy chủ | `localhost` (hoặc IP máy đang chạy Docker) |
| Cổng | `27017` (`MONGO_PORT`) |
| Tài khoản | `admin` (`MONGO_ROOT_USERNAME`) |
| Mật khẩu | `MONGO_ROOT_PASSWORD` trong file `.env` |
| Xác thực (authentication database) | `admin` (`authSource=admin`) |
| Database | `QuanLyToaNha` |
| Collection | `toanha`, `hopdong_thue`, `nhatky_dichvu` |

Chuỗi kết nối đầy đủ (dùng cho ô "URI" của Compass):

```
mongodb://admin:MAT_KHAU_CUA_BAN@localhost:27017/?authSource=admin
```

Nếu mật khẩu có ký tự đặc biệt (`@`, `:`, `/`, `#`, `%`), phải mã hóa URL, ví dụ `@` thành `%40`.

## 2. Các bước trong Compass

1. Mở MongoDB Compass, chọn **Add new connection**.
2. Chọn **Fill in connection fields individually** (hoặc dán chuỗi URI ở trên vào ô URI rồi bấm **Connect**).
3. Nhập:
   - **Hostname**: `localhost`
   - **Port**: `27017`
   - **Authentication**: `Username / Password`
   - **Username**: `admin`
   - **Password**: mật khẩu trong `.env`
   - **Authentication Database**: `admin`
4. Bấm **Connect**.
5. Trong danh sách database, mở `QuanLyToaNha` rồi chọn collection muốn xem.

Kết quả mong đợi: 3 collection `toanha` (3 tài liệu), `hopdong_thue` (6 tài liệu), `nhatky_dichvu` (7.320 tài liệu).

## 3. Thử truy vấn nhanh

Trong tab **Aggregations** của collection `nhatky_dichvu`, hoặc tab **Filter** của `toanha`:

```javascript
// toanha: tìm tòa nhà TN02 (Filter)
{ "maToaNha": "TN02" }

// nhatky_dichvu: đếm nhật ký theo tòa nhà (Aggregation)
[ { "$group": { "_id": "$maToaNha", "soLuot": { "$sum": 1 } } } ]
```

## 4. Kết nối từ máy khác trong mạng nội bộ

1. Trên máy đang chạy Docker, tìm IP LAN (ví dụ `192.168.1.20`).
2. Đảm bảo tường lửa cho phép cổng `27017` từ máy khách.
3. Trong Compass dùng Hostname là IP đó, các thông tin còn lại giữ nguyên.

Chỉ mở cổng khi cần, và không công khai ra Internet: cấu hình này chưa bật TLS.

## 5. Xử lý lỗi thường gặp

| Lỗi | Nguyên nhân và cách sửa |
| :--- | :--- |
| `Authentication failed` | Sai mật khẩu, hoặc thiếu `authSource=admin` / Authentication Database chưa là `admin`. |
| `ECONNREFUSED` / `getaddrinfo` | Container `office_mongodb` chưa chạy (`docker compose ps`), hoặc sai cổng. |
| Không thấy collection | Database đang mở không phải `QuanLyToaNha`; hoặc `db-init` chưa chạy xong (xem `docker compose logs db-init`). |
| Lỗi `Server selection timed out` từ máy khác | Tường lửa chặn cổng 27017, hoặc `MONGO_PORT` chưa được publish. |
