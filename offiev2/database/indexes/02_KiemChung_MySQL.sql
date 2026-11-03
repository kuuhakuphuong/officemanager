/* ============================================================================
   KIỂM CHỨNG CHỈ MỤC MYSQL (officev2) - chạy SAU 01_ChiMuc_TimKiem_MySQL.sql
   Mỗi truy vấn EXPLAIN phải dùng chỉ mục tương ứng ở cột "key".
   Ví dụ đọc kết quả: key = IX_HopDongThue_CongTy_Ngay, type = ref/range (không phải ALL).
   ============================================================================ */
USE QLToaNha_BCNF;

-- 1. Lọc công ty theo lĩnh vực -> kỳ vọng key = IX_CongTy_LinhVuc
EXPLAIN SELECT MaCongTy, TenCongTy FROM CongTy WHERE LinhVuc = N'Thương mại';

-- 2. Hiệu lực hợp đồng của công ty -> kỳ vọng key = IX_HopDongThue_CongTy_Ngay
EXPLAIN SELECT MaHopDong FROM HopDongThue WHERE MaCongTy = 'CT01' AND NgayBatDau <= CURDATE();

-- 3. Nhân viên theo công ty, sắp theo họ tên -> kỳ vọng key = IX_NhanVienCongTy_CongTy_Ten
EXPLAIN SELECT MaNVCT, HoTen FROM NhanVienCongTy WHERE MaCongTy = 'CT01' ORDER BY HoTen;

-- 4. Nhân viên tòa theo loại -> kỳ vọng key = IX_NhanVienToaNha_Loai
EXPLAIN SELECT MaNVTN FROM NhanVienToaNha WHERE MaToaNha = 'TN01' AND LoaiNV = 'QUAN_LY';

-- 5. Hóa đơn chưa thanh toán / đã thanh toán theo ngày -> kỳ vọng key = IX_HoaDonThang_TrangThai_Ngay
EXPLAIN SELECT MaHoaDon FROM HoaDonThang WHERE TrangThai = 'DA_THANH_TOAN' AND NgayThanhToan BETWEEN '2026-08-01' AND '2026-09-30';

-- 6. Nhật ký theo ngày -> kỳ vọng key = IX_ChiTietSuDungNV_Ngay
EXPLAIN SELECT MaSuDung FROM ChiTietSuDungNV WHERE NgaySuDung = '2026-08-03';

-- Kiểm tra chỉ mục đã tạo đúng cột:
SELECT TABLE_NAME, INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS cot
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE() AND INDEX_NAME LIKE 'IX_%'
GROUP BY TABLE_NAME, INDEX_NAME;
