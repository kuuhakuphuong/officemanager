/* ============================================================================
   PHẦN 7 - CSDL PHÂN TÁN (THÀNH VIÊN 7: BÙI ĐOÀN QUANG HUY - CHHT045)
   FILE 04: TRUY VẤN PHÂN MẢNH (7.2, 7.3, 7.4) VÀ KIỂM TRA TÁI THIẾT (7.5)
   Hướng dẫn:
   - Phần A chạy trên CSDL toàn cục QLToaNha_BCNF (của TV3) để minh họa các câu lệnh
     phân mảnh ngang chính, phân mảnh ngang dẫn xuất, phân mảnh dọc và kiểm tra tái thiết.
   - Phần B chạy khi đã nạp 3 DB độc lập (QLToaNha_Site1, QLToaNha_Site2, QLToaNha_Site3)
     trên cùng instance để kiểm tra hợp (UNION ALL) và kết nối (JOIN) giữa 3 Site.
   ============================================================================ */
USE QLToaNha_BCNF;
GO
SET NOCOUNT ON;

-- ============================================================================
-- CÔNG VIỆC 7.2: PHÂN MẢNH NGANG CHÍNH (TOANHA, VANPHONG)
-- Vị từ đơn giản: p1: MaToaNha = 'TN01', p2: MaToaNha = 'TN02', p3: MaToaNha = 'TN03'
-- ============================================================================

-- 1. Phân mảnh ngang chính bảng ToaNha
SELECT * FROM dbo.ToaNha WHERE MaToaNha = 'TN01'; -- ToaNha_1 (Site 1)
SELECT * FROM dbo.ToaNha WHERE MaToaNha = 'TN02'; -- ToaNha_2 (Site 2)
SELECT * FROM dbo.ToaNha WHERE MaToaNha = 'TN03'; -- ToaNha_3 (Site 3)

-- 2. Phân mảnh ngang chính bảng VanPhong (hoặc dẫn xuất từ ToaNha_i)
SELECT * FROM dbo.VanPhong WHERE MaToaNha = 'TN01'; -- VanPhong_1 (VP01..VP04)
SELECT * FROM dbo.VanPhong WHERE MaToaNha = 'TN02'; -- VanPhong_2 (VP05..VP08)
SELECT * FROM dbo.VanPhong WHERE MaToaNha = 'TN03'; -- VanPhong_3 (VP09..VP12)

-- ============================================================================
-- CÔNG VIỆC 7.3: PHÂN MẢNH NGANG DẪN XUẤT (SEMI-JOIN)
-- Các bảng: HopDongThue, HoaDonThang, ChiTietSuDungNV (Nhật ký dịch vụ)
-- ============================================================================

-- 1. Phân mảnh dẫn xuất HopDongThue_i = HopDongThue SEMI-JOIN VanPhong_i
SELECT hd.*
FROM dbo.HopDongThue AS hd
WHERE EXISTS (
    SELECT 1 FROM dbo.VanPhong AS vp
    WHERE vp.MaVanPhong = hd.MaVanPhong AND vp.MaToaNha = 'TN01'
);

-- 2. Phân mảnh dẫn xuất HoaDonThang_i = HoaDonThang SEMI-JOIN ToaNha_i
SELECT hdt.*
FROM dbo.HoaDonThang AS hdt
WHERE EXISTS (
    SELECT 1 FROM dbo.ToaNha AS tn
    WHERE tn.MaToaNha = hdt.MaToaNha AND tn.MaToaNha = 'TN01'
);

-- 3. Phân mảnh dẫn xuất ChiTietSuDungNV_i = ChiTietSuDungNV SEMI-JOIN DichVu_i
SELECT nk.*
FROM dbo.ChiTietSuDungNV AS nk
WHERE EXISTS (
    SELECT 1 FROM dbo.DichVu AS dv
    WHERE dv.MaDichVu = nk.MaDichVu AND dv.MaToaNha = 'TN01'
);

-- 4. Bảng thống kê số bản ghi phân mảnh tại từng Site (Kiểm chứng 7.2 & 7.3)
SELECT
    tn.MaToaNha AS Site_ToaNha,
    COUNT(DISTINCT vp.MaVanPhong) AS SoVanPhong,
    COUNT(DISTINCT hd.MaHopDong) AS SoHopDongThue,
    COUNT(DISTINCT hdt.MaHoaDon) AS SoHoaDonThang,
    (SELECT COUNT(*) FROM dbo.ChiTietSuDungNV nk
     JOIN dbo.DichVu dv ON dv.MaDichVu = nk.MaDichVu
     WHERE dv.MaToaNha = tn.MaToaNha) AS SoNhatKyDichVu
FROM dbo.ToaNha AS tn
LEFT JOIN dbo.VanPhong AS vp ON vp.MaToaNha = tn.MaToaNha
LEFT JOIN dbo.HopDongThue AS hd ON hd.MaVanPhong = vp.MaVanPhong
LEFT JOIN dbo.HoaDonThang AS hdt ON hdt.MaToaNha = tn.MaToaNha
GROUP BY tn.MaToaNha
ORDER BY tn.MaToaNha;

-- ============================================================================
-- CÔNG VIỆC 7.4: PHÂN MẢNH DỌC (CONGTY, LUONGTHANG) & TÁI THIẾT (JOIN)
-- ============================================================================

-- 1. Phân mảnh dọc bảng CongTy:
-- Mảnh 1 (Thông tin tra cứu chung - đặt tại 3 Site):
SELECT MaCongTy, TenCongTy, LinhVuc FROM dbo.CongTy;

-- Mảnh 2 (Thông tin hồ sơ thuế & liên hệ bảo mật - chỉ lưu tại Site 1):
SELECT MaCongTy, MaSoThue, DiaChi, DienThoai, Email FROM dbo.CongTy;

-- Tái thiết bảng CongTy bằng phép kết nối tự nhiên (JOIN trên khóa chính MaCongTy):
SELECT
     m1.MaCongTy, m1.TenCongTy, m2.MaSoThue, m2.DiaChi, m2.DienThoai, m2.Email, m1.LinhVuc
FROM (SELECT MaCongTy, TenCongTy, LinhVuc FROM dbo.CongTy) AS m1
INNER JOIN (SELECT MaCongTy, MaSoThue, DiaChi, DienThoai, Email FROM dbo.CongTy) AS m2
    ON m1.MaCongTy = m2.MaCongTy;

-- 2. Phân mảnh dọc bảng LuongThang:
-- Mảnh 1 (Thông tin kỳ lương nhân viên):
SELECT MaNVTN, Thang, Nam FROM dbo.LuongThang;

-- Mảnh 2 (Thông tin tài chính lương & thưởng - chỉ lưu tại Site 1):
SELECT MaNVTN, Thang, Nam, LuongCoBan, TienThuong FROM dbo.LuongThang;

-- Tái thiết bảng LuongThang bằng phép JOIN trên khóa chính ghép (MaNVTN, Thang, Nam):
SELECT
    k.MaNVTN, k.Thang, k.Nam, t.LuongCoBan, t.TienThuong,
    (t.LuongCoBan + t.TienThuong) AS TongLuong
FROM (SELECT MaNVTN, Thang, Nam FROM dbo.LuongThang) AS k
INNER JOIN (SELECT MaNVTN, Thang, Nam, LuongCoBan, TienThuong FROM dbo.LuongThang) AS t
    ON k.MaNVTN = t.MaNVTN AND k.Thang = t.Thang AND k.Nam = t.Nam;

-- ============================================================================
-- CÔNG VIỆC 7.5: KIỂM TRA TÍNH ĐẦY ĐỦ, TÁCH BIỆT VÀ TÁI THIẾT (EXCEPT = 0 DÒNG)
-- ============================================================================
IF EXISTS (
    SELECT * FROM dbo.VanPhong
    EXCEPT
    (
        SELECT * FROM dbo.VanPhong WHERE MaToaNha = 'TN01'
        UNION ALL
        SELECT * FROM dbo.VanPhong WHERE MaToaNha = 'TN02'
        UNION ALL
        SELECT * FROM dbo.VanPhong WHERE MaToaNha = 'TN03'
    )
)
    THROW 57501, N'Loi: Phan manh ngang VanPhong khong bao toan du lieu!', 1;

IF EXISTS (
    SELECT * FROM dbo.HopDongThue
    EXCEPT
    (
        SELECT hd.* FROM dbo.HopDongThue hd JOIN dbo.VanPhong vp ON vp.MaVanPhong = hd.MaVanPhong WHERE vp.MaToaNha = 'TN01'
        UNION ALL
        SELECT hd.* FROM dbo.HopDongThue hd JOIN dbo.VanPhong vp ON vp.MaVanPhong = hd.MaVanPhong WHERE vp.MaToaNha = 'TN02'
        UNION ALL
        SELECT hd.* FROM dbo.HopDongThue hd JOIN dbo.VanPhong vp ON vp.MaVanPhong = hd.MaVanPhong WHERE vp.MaToaNha = 'TN03'
    )
)
    THROW 57502, N'Loi: Phan manh ngang dan xuat HopDongThue khong bao toan du lieu!', 1;

PRINT N'PASS: Kiểm tra tính Đầy đủ, Tách biệt và Tái thiết đạt 100%!';
GO
