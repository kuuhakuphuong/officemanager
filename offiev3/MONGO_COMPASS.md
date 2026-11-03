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
| Collection | `toa_nha`, `hop_dong_thue`, `hoa_don_thang`, `nhat_ky_su_dung`, `bang_luong`, `cong_ty`, `nhan_vien_cong_ty`, `chi_phi_van_hanh`, `bo_dem`, `thong_so`, `vi_tri`, `loai_dich_vu`, `bac_cong_viec` |

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

Kết quả mong đợi: `toa_nha` có 3 tài liệu (mỗi tòa một tài liệu), `hop_dong_thue` có 12, `hoa_don_thang` có 12, `nhat_ky_su_dung` có 2793.

## 3. Thử truy vấn nhanh

Trong tab **Aggregations** của collection `nhat_ky_su_dung`, hoặc tab **Filter** của `toa_nha`:

```javascript
// toa_nha: tìm tòa nhà TN02 (Filter)
{ "maToaNha": "TN02" }

// nhat_ky_su_dung: đếm nhật ký theo tòa nhà (Aggregation)
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
