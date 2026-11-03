# Tổng hợp chỉ mục (index) theo phiên bản

Tài liệu này liệt kê mọi chỉ mục đã đánh trong ba phiên bản, trạng thái áp dụng và cách kiểm chứng.

| Phiên bản | Thư mục | Trạng thái chỉ mục mới |
| :--- | :--- | :--- |
| Bản 1 (SQL Server gốc) | `D:\ptit_csdl_officebuilding` | Không thêm chỉ mục nào (theo yêu cầu giữ nguyên CSDL) |
| Bản 2 (MySQL) | `offiev2` | 6 chỉ mục mới **chưa áp dụng** vào CSDL đang chạy; file sẵn sàng |
| Bản 3 (MongoDB) | `offiev3` | 10 chỉ mục **đã áp dụng** khi nạp dữ liệu (`seed.js`) |

## 0. Tóm tắt: những chỉ mục tôi đã đánh (không tính chỉ mục có sẵn trong schema)

| # | Bản | Tên chỉ mục | Bảng / collection | Cột | Trạng thái |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | 2 (MySQL) | IX_CongTy_LinhVuc | CongTy | LinhVuc | Chưa áp dụng |
| 2 | 2 (MySQL) | IX_HopDongThue_CongTy_Ngay | HopDongThue | MaCongTy, NgayBatDau | Chưa áp dụng |
| 3 | 2 (MySQL) | IX_NhanVienCongTy_CongTy_Ten | NhanVienCongTy | MaCongTy, HoTen | Chưa áp dụng |
| 4 | 2 (MySQL) | IX_NhanVienToaNha_Loai | NhanVienToaNha | MaToaNha, LoaiNV | Chưa áp dụng |
| 5 | 2 (MySQL) | IX_HoaDonThang_TrangThai_Ngay | HoaDonThang | TrangThai, NgayThanhToan | Chưa áp dụng |
| 6 | 2 (MySQL) | IX_ChiTietSuDungNV_Ngay | ChiTietSuDungNV | NgaySuDung | Chưa áp dụng |
| 7 | 3 (MongoDB) | cong_ty `{ linhVuc: 1 }` | cong_ty | linhVuc | Đã áp dụng |
| 8 | 3 (MongoDB) | hop_dong_thue `{ maCongTy: 1, ngayBatDau: 1 }` | hop_dong_thue | maCongTy, ngayBatDau | Đã áp dụng |
| 9 | 3 (MongoDB) | hop_dong_thue `{ maVanPhong: 1, ngayKetThuc: 1 }` | hop_dong_thue | maVanPhong, ngayKetThuc | Đã áp dụng |
| 10 | 3 (MongoDB) | nhan_vien_cong_ty `{ maCongTy: 1, hoTen: 1 }` | nhan_vien_cong_ty | maCongTy, hoTen | Đã áp dụng |
| 11 | 3 (MongoDB) | toa_nha `{ "vanPhong.maVanPhong": 1 }` | toa_nha | vanPhong.maVanPhong | Đã áp dụng |
| 12 | 3 (MongoDB) | toa_nha `{ "dichVu.maDichVu": 1 }` | toa_nha | dichVu.maDichVu | Đã áp dụng |
| 13 | 3 (MongoDB) | hoa_don_thang `{ maToaNha: 1, maHoaDon: 1 }` (unique) | hoa_don_thang | maToaNha, maHoaDon | Đã áp dụng |
| 14 | 3 (MongoDB) | hoa_don_thang `{ maToaNha: 1, maCongTy: 1, nam: 1, thang: 1 }` (unique) | hoa_don_thang | maToaNha, maCongTy, nam, thang | Đã áp dụng |
| 15 | 3 (MongoDB) | nhat_ky_su_dung `{ maToaNha: 1, maNVCT: 1, maDichVu: 1, ngaySuDung: 1 }` (unique) | nhat_ky_su_dung | maToaNha, maNVCT, maDichVu, ngaySuDung | Đã áp dụng |
| 16 | 3 (MongoDB) | bang_luong `{ maToaNha: 1, maNVTN: 1, nam: 1, thang: 1 }` (unique) | bang_luong | maToaNha, maNVTN, nam, thang | Đã áp dụng |

Bản 1 (SQL Server gốc): không có chỉ mục nào do tôi thêm.

Các chỉ mục ở mục 1.1 bên dưới là chỉ mục **có sẵn trong schema gốc**, không phải do tôi thêm.

## 1. Bản 2 (MySQL, `offiev2`)

### 1.1. Chỉ mục gốc đã có trong schema (17 chỉ mục, đã áp dụng)

Định nghĩa trong `database/schema/01_CreateSchema_TV3_NguyenThiLanAnh.sql`:

| Bảng | Chỉ mục | Cột |
| :--- | :--- | :--- |
| VanPhong | IX_VanPhong_ToaNha | MaToaNha |
| VanPhong | IX_VanPhong_ViTri | MaViTri |
| HopDongThue | IX_HopDongThue_VanPhong_Ngay | MaVanPhong, NgayBatDau, NgayKetThuc |
| HopDongThue | IX_HopDongThue_CongTy | MaCongTy |
| NhanVienCongTy | IX_NhanVienCongTy_CongTy | MaCongTy |
| DichVu | IX_DichVu_Loai | MaLoaiDV |
| SuDungDichVu | IX_SuDungDichVu_DichVu | MaDichVu, NgayBatDau, NgayKetThuc |
| ChiTietSuDungNV | IX_ChiTietSuDungNV_DichVu_Ngay | MaDichVu, NgaySuDung |
| NhanVienToaNha | IX_NhanVienToaNha_ToaNha | MaToaNha |
| NhanVienToaNha | IX_NhanVienToaNha_QuanLy | MaQuanLy |
| PhanCongNVTN | IX_PhanCongNVTN_DichVu | MaDichVu |
| PhanCongNVTN | IX_PhanCongNVTN_Bac | MaBac |
| HoaDonThang | IX_HoaDonThang_ToaNha_Ky | MaToaNha, Nam, Thang |
| ChiTietHoaDon | IX_ChiTietHoaDon_HoaDon | MaHoaDon |
| ChiTietHoaDon | IX_ChiTietHoaDon_VanPhong | MaVanPhong |
| ChiTietHoaDon | IX_ChiTietHoaDon_DichVu | MaDichVu |
| ChiPhiVanHanh | IX_ChiPhiVanHanh_ToaNha_Ky | MaToaNha, Nam, Thang |

### 1.2. Chỉ mục mới cho tìm kiếm và lọc (6 chỉ mục, **chưa áp dụng**)

File: `offiev2/database/indexes/01_ChiMuc_TimKiem_MySQL.sql`

| Chỉ mục | Bảng | Cột | Phục vụ |
| :--- | :--- | :--- | :--- |
| IX_CongTy_LinhVuc | CongTy | LinhVuc | Lọc công ty theo lĩnh vực |
| IX_HopDongThue_CongTy_Ngay | HopDongThue | MaCongTy, NgayBatDau | Hợp đồng theo công ty và hiệu lực |
| IX_NhanVienCongTy_CongTy_Ten | NhanVienCongTy | MaCongTy, HoTen | Nhân viên theo công ty, sắp theo tên |
| IX_NhanVienToaNha_Loai | NhanVienToaNha | MaToaNha, LoaiNV | Lọc nhân viên tòa theo loại |
| IX_HoaDonThang_TrangThai_Ngay | HoaDonThang | TrangThai, NgayThanhToan | Báo cáo thu và hóa đơn chưa thanh toán |
| IX_ChiTietSuDungNV_Ngay | ChiTietSuDungNV | NgaySuDung | Nhật ký theo ngày |

Kiểm chứng: `database/indexes/02_KiemChung_MySQL.sql` (chạy `EXPLAIN` từng truy vấn, cột `key` phải là tên chỉ mục tương ứng). Trước khi áp dụng, `EXPLAIN` cho thấy truy vấn đang dùng chỉ mục khác hoặc quét toàn bộ bảng; sau khi áp dụng phải đổi sang chỉ mục mới.

Cách áp dụng (chạy một lần):
```
docker exec -i -e MYSQL_PWD=<mật khẩu> office_mysql_central mysql -uroot QLToaNha_BCNF < offiev2/database/indexes/01_ChiMuc_TimKiem_MySQL.sql
```

### 1.3. Kiểm tra đã áp dụng

```
docker exec -e MYSQL_PWD=<mật khẩu> office_mysql_central mysql -uroot -e "SELECT TABLE_NAME, INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA='QLToaNha_BCNF' AND INDEX_NAME LIKE 'IX\_%' GROUP BY TABLE_NAME, INDEX_NAME;"
```

Lúc kiểm tra gần nhất, 6 chỉ mục mục 1.2 chưa có trong CSDL.

## 2. Bản 3 (MongoDB, `offiev3`)

Định nghĩa: `database/seed/seed.js` (hàm `load`). Tạo khi container `db-init` nạp dữ liệu, nên đã có trong cụm đang chạy.

| Collection | Chỉ mục | Loại | Phục vụ |
| :--- | :--- | :--- | :--- |
| cong_ty | `{ linhVuc: 1 }` | thường | Lọc công ty theo lĩnh vực |
| hop_dong_thue | `{ maCongTy: 1, ngayBatDau: 1 }` | thường | Hợp đồng theo công ty và hiệu lực |
| hop_dong_thue | `{ maVanPhong: 1, ngayKetThuc: 1 }` | thường | Kiểm tra chồng lịch thuê |
| nhan_vien_cong_ty | `{ maCongTy: 1, hoTen: 1 }` | thường | Nhân viên theo công ty, sắp theo tên |
| toa_nha | `{ "vanPhong.maVanPhong": 1 }` | multikey | Tra cứu văn phòng trong mảng nhúng |
| toa_nha | `{ "dichVu.maDichVu": 1 }` | multikey | Tra cứu dịch vụ trong mảng nhúng |
| hoa_don_thang | `{ maToaNha: 1, maHoaDon: 1 }` | unique | Khóa hóa đơn |
| hoa_don_thang | `{ maToaNha: 1, maCongTy: 1, nam: 1, thang: 1 }` | unique | Một hóa đơn cho mỗi công ty trong một tháng |
| nhat_ky_su_dung | `{ maToaNha: 1, maNVCT: 1, maDichVu: 1, ngaySuDung: 1 }` | unique | Chặn ghi trùng nhật ký |
| bang_luong | `{ maToaNha: 1, maNVTN: 1, nam: 1, thang: 1 }` | unique | Một bản ghi lương cho mỗi nhân viên trong một tháng |

Chỉ mục khóa phân mảnh (`maToaNha`, `_id` băm, `maCongTy` băm) do MongoDB tạo khi `shardCollection`.

Kiểm chứng (trong `mongosh` đã xác thực, kết nối `mongos`):
```
use QuanLyToaNha
db.hop_dong_thue.getIndexes()                       // phải có maCongTy_1_ngayBatDau_1 và maVanPhong_1_ngayKetThuc_1
db.hop_dong_thue.find({ maCongTy: "CT01", ngayBatDau: { $lte: "2026-11-03" } }).explain("executionStats")
// winningPlan phải là IXSCAN trên maCongTy_1_ngayBatDau_1 (không phải COLLSCAN)
```

Mô tả chi tiết và ghi chú shard: `offiev3/docs/CHI_MUC_INDEX.md`.

## 3. Bản 1 (SQL Server gốc)

Không thêm chỉ mục nào. Theo yêu cầu, bản này không thay đổi cơ sở dữ liệu. Bản 1 chỉ có các chỉ mục sẵn có trong schema T-SQL (`database/schema/01_CreateSchema_TV3_NguyenThiLanAnh.sql` của dự án gốc).

## 4. Nguyên tắc

- Mỗi chỉ mục mới phải có file SQL/JS định nghĩa, và có cách kiểm chứng (`EXPLAIN`, `explain()` hoặc `getIndexes()`).
- Chỉ mục chỉ có tác dụng với truy vấn dùng đúng cột. Tìm kiếm chuỗi có dấu tiếng Việt đang lọc trong bộ nhớ, nên các chỉ mục trên không giúp phần đó.
