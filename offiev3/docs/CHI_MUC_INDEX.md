# Chỉ mục MongoDB (officev3)

Nơi tạo: `database/seed/seed.js` (hàm `load`), chạy tự động trong container `db-init`.

| Collection | Chỉ mục | Loại | Phục vụ |
| :--- | :--- | :--- | :--- |
| `cong_ty` | `{ linhVuc: 1 }` | thường | Lọc công ty theo lĩnh vực (`store.companyQuery`) |
| `hop_dong_thue` | `{ maCongTy: 1, ngayBatDau: 1 }` | thường | Lọc hợp đồng theo công ty và hiệu lực |
| `hop_dong_thue` | `{ maVanPhong: 1, ngayKetThuc: 1 }` | thường | Kiểm tra chồng lịch thuê theo văn phòng |
| `nhan_vien_cong_ty` | `{ maCongTy: 1, hoTen: 1 }` | thường | Lọc nhân viên theo công ty, sắp xếp theo tên |
| `toa_nha` | `{ "vanPhong.maVanPhong": 1 }` | multikey | Tra cứu văn phòng trong mảng nhúng |
| `toa_nha` | `{ "dichVu.maDichVu": 1 }` | multikey | Tra cứu dịch vụ trong mảng nhúng |
| `hoa_don_thang` | `{ maToaNha: 1, maHoaDon: 1 }` | unique | Khóa hóa đơn (chứa khóa phân mảnh) |
| `hoa_don_thang` | `{ maToaNha: 1, maCongTy: 1, nam: 1, thang: 1 }` | unique | Một hóa đơn cho mỗi công ty trong một tháng |
| `nhat_ky_su_dung` | `{ maToaNha: 1, maNVCT: 1, maDichVu: 1, ngaySuDung: 1 }` | unique | Chặn ghi trùng nhật ký |
| `bang_luong` | `{ maToaNha: 1, maNVTN: 1, nam: 1, thang: 1 }` | unique | Một bản ghi lương cho mỗi nhân viên trong một tháng |

Chỉ mục khóa phân mảnh (`maToaNha`, `_id` băm, `maCongTy` băm) do MongoDB tạo khi `shardCollection`.

Đề xuất thêm (chưa làm): `hoa_don_thang { trangThai: 1, ngayThanhToan: 1 }` cho báo cáo thu chi, và trường tìm kiếm đã chuẩn hóa dấu (có chỉ mục) để tìm chuỗi nhanh khi dữ liệu lớn.
