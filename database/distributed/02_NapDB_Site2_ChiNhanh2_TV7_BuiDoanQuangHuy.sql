/* ============================================================================
   PHẦN 7 - CSDL PHÂN TÁN (THÀNH VIÊN 7: BÙI ĐOÀN QUANG HUY - CHHT045)
   KỊCH BẢN NẠP ĐỘC LẬP CHO SERVER SITE 2: QLToaNha_Site2
   Vai trò: CHI NHÁNH 2 (TN02): Chỉ chứa mảnh dữ liệu của TN02 và danh mục tra cứu (đã tách cột bảo mật tài chính về Site 1)
   Đặc điểm: Chạy độc lập 100% trên máy chủ SQL Server của Site 2
             (Tự tạo Database, tạo bảng vật lý và nạp dữ liệu chuẩn từ Phần 3)
   ============================================================================ */
USE master;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_ID(N'QLToaNha_Site2') IS NOT NULL
BEGIN
    ALTER DATABASE [QLToaNha_Site2] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [QLToaNha_Site2];
END;
GO

CREATE DATABASE [QLToaNha_Site2];
GO
USE [QLToaNha_Site2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRANSACTION;

-- ============================================================================
-- 1. CÁC BẢNG DANH MỤC (NHÂN BẢN TỪ SITE 1)
-- ============================================================================
CREATE TABLE dbo.ThamSo (
    TenThamSo varchar(50) NOT NULL CONSTRAINT PK_ThamSo PRIMARY KEY,
    GiaTri decimal(18,6) NOT NULL,
    MoTa nvarchar(300) NOT NULL
);

CREATE TABLE dbo.ViTri (
    MaViTri varchar(20) NOT NULL CONSTRAINT PK_ViTri PRIMARY KEY,
    TenViTri nvarchar(100) NOT NULL CONSTRAINT UQ_ViTri_Ten UNIQUE,
    DonGiaThueM2 decimal(18,2) NOT NULL
);

CREATE TABLE dbo.LoaiDichVu (
    MaLoaiDV varchar(20) NOT NULL CONSTRAINT PK_LoaiDichVu PRIMARY KEY,
    TenLoai nvarchar(100) NOT NULL CONSTRAINT UQ_LoaiDichVu_Ten UNIQUE,
    KieuTinhPhi varchar(10) NOT NULL,
    CoTinhTheoNguoi bit NOT NULL,
    CoTinhTheoDienTich bit NOT NULL
);

-- Bảng BacCongViec_TraCuu (Đã chiếu bỏ cột đơn giá lương tại chi nhánh)
CREATE TABLE dbo.BacCongViec_TraCuu (
    MaBac varchar(20) NOT NULL CONSTRAINT PK_BacCongViec_TraCuu PRIMARY KEY,
    TenBac nvarchar(100) NOT NULL CONSTRAINT UQ_BacCongViec_TraCuu_Ten UNIQUE
);

-- ============================================================================
-- 2. CÁC MẢNH DỌC CỦA BẢNG CONGTY (MỤC 7.4)
-- ============================================================================
-- Mảnh 1: CongTy_TraCuu (Nhân bản ở cả 3 Site để phục vụ tra cứu tên công ty)
CREATE TABLE dbo.CongTy_TraCuu (
    MaCongTy varchar(20) NOT NULL CONSTRAINT PK_CongTy_TraCuu PRIMARY KEY,
    TenCongTy nvarchar(200) NOT NULL,
    LinhVuc nvarchar(100) NOT NULL
);

-- ============================================================================
-- 3. CÁC MẢNH NGANG CHÍNH TẠI SITE 2 (MaToaNha = 'TN02') - MỤC 7.2
-- ============================================================================
CREATE TABLE dbo.ToaNha (
    MaToaNha varchar(20) NOT NULL CONSTRAINT PK_ToaNha PRIMARY KEY,
    TenToaNha nvarchar(150) NOT NULL,
    DiaChi nvarchar(300) NOT NULL,
    SoTang smallint NOT NULL,
    CONSTRAINT CK_ToaNha_Site2 CHECK (MaToaNha = 'TN02')
);

CREATE TABLE dbo.VanPhong (
    MaVanPhong varchar(20) NOT NULL CONSTRAINT PK_VanPhong PRIMARY KEY,
    MaToaNha varchar(20) NOT NULL,
    MaViTri varchar(20) NOT NULL,
    Tang smallint NOT NULL,
    DienTich decimal(10,2) NOT NULL,
    CONSTRAINT FK_VanPhong_ToaNha FOREIGN KEY (MaToaNha) REFERENCES dbo.ToaNha(MaToaNha),
    CONSTRAINT FK_VanPhong_ViTri FOREIGN KEY (MaViTri) REFERENCES dbo.ViTri(MaViTri),
    CONSTRAINT CK_VanPhong_Site2 CHECK (MaToaNha = 'TN02')
);

CREATE TABLE dbo.DichVu (
    MaDichVu varchar(20) NOT NULL CONSTRAINT PK_DichVu PRIMARY KEY,
    MaToaNha varchar(20) NOT NULL,
    MaLoaiDV varchar(20) NOT NULL,
    TenDichVu nvarchar(120) NOT NULL,
    DonGiaCoBan decimal(18,2) NOT NULL,
    CONSTRAINT FK_DichVu_ToaNha FOREIGN KEY (MaToaNha) REFERENCES dbo.ToaNha(MaToaNha),
    CONSTRAINT FK_DichVu_LoaiDichVu FOREIGN KEY (MaLoaiDV) REFERENCES dbo.LoaiDichVu(MaLoaiDV),
    CONSTRAINT CK_DichVu_Site2 CHECK (MaToaNha = 'TN02')
);

CREATE TABLE dbo.NhanVienToaNha (
    MaNVTN varchar(20) NOT NULL CONSTRAINT PK_NhanVienToaNha PRIMARY KEY,
    MaToaNha varchar(20) NOT NULL,
    MaQuanLy varchar(20) NULL,
    LoaiNV varchar(10) NOT NULL,
    HoTen nvarchar(150) NOT NULL,
    GioiTinh char(1) NOT NULL,
    NgaySinh date NOT NULL,
    DienThoai varchar(20) NULL,
    Email varchar(254) NULL,
    NgayVaoLam date NOT NULL,
    CONSTRAINT FK_NhanVienToaNha_ToaNha FOREIGN KEY (MaToaNha) REFERENCES dbo.ToaNha(MaToaNha),
    CONSTRAINT FK_NhanVienToaNha_QuanLy FOREIGN KEY (MaQuanLy) REFERENCES dbo.NhanVienToaNha(MaNVTN),
    CONSTRAINT CK_NhanVienToaNha_Site2 CHECK (MaToaNha = 'TN02')
);

CREATE TABLE dbo.HoaDonThang (
    MaHoaDon int NOT NULL CONSTRAINT PK_HoaDonThang PRIMARY KEY,
    MaCongTy varchar(20) NOT NULL,
    MaToaNha varchar(20) NOT NULL,
    Thang tinyint NOT NULL,
    Nam smallint NOT NULL,
    NgayLap date NOT NULL,
    TrangThai varchar(20) NOT NULL,
    NgayThanhToan date NULL,
    NguoiThu nvarchar(100) NULL,
    CONSTRAINT FK_HoaDonThang_CongTy FOREIGN KEY (MaCongTy) REFERENCES dbo.CongTy_TraCuu(MaCongTy),
    CONSTRAINT FK_HoaDonThang_ToaNha FOREIGN KEY (MaToaNha) REFERENCES dbo.ToaNha(MaToaNha),
    CONSTRAINT UQ_HoaDonThang_Ky UNIQUE (MaCongTy, MaToaNha, Thang, Nam),
    CONSTRAINT CK_HoaDonThang_Site2 CHECK (MaToaNha = 'TN02')
);

CREATE TABLE dbo.ChiPhiVanHanh (
    MaChiPhi bigint NOT NULL CONSTRAINT PK_ChiPhiVanHanh PRIMARY KEY,
    MaToaNha varchar(20) NOT NULL,
    Thang tinyint NOT NULL,
    Nam smallint NOT NULL,
    LoaiChiPhi nvarchar(100) NOT NULL,
    SoTien decimal(18,2) NOT NULL,
    MoTa nvarchar(300) NOT NULL,
    CONSTRAINT FK_ChiPhiVanHanh_ToaNha FOREIGN KEY (MaToaNha) REFERENCES dbo.ToaNha(MaToaNha),
    CONSTRAINT CK_ChiPhiVanHanh_Site2 CHECK (MaToaNha = 'TN02')
);

-- ============================================================================
-- 4. CÁC MẢNH NGANG DẪN XUẤT TẠI SITE 2 (SEMI-JOIN) - MỤC 7.3
-- ============================================================================
CREATE TABLE dbo.HopDongThue (
    MaHopDong varchar(20) NOT NULL CONSTRAINT PK_HopDongThue PRIMARY KEY,
    MaCongTy varchar(20) NOT NULL,
    MaVanPhong varchar(20) NOT NULL,
    NgayBatDau date NOT NULL,
    NgayKetThuc date NULL,
    CONSTRAINT FK_HopDongThue_CongTy FOREIGN KEY (MaCongTy) REFERENCES dbo.CongTy_TraCuu(MaCongTy),
    CONSTRAINT FK_HopDongThue_VanPhong FOREIGN KEY (MaVanPhong) REFERENCES dbo.VanPhong(MaVanPhong)
);

CREATE TABLE dbo.SuDungDichVu (
    MaCongTy varchar(20) NOT NULL,
    MaDichVu varchar(20) NOT NULL,
    NgayBatDau date NOT NULL,
    NgayKetThuc date NULL,
    CONSTRAINT PK_SuDungDichVu PRIMARY KEY (MaCongTy, MaDichVu, NgayBatDau),
    CONSTRAINT FK_SuDungDichVu_CongTy FOREIGN KEY (MaCongTy) REFERENCES dbo.CongTy_TraCuu(MaCongTy),
    CONSTRAINT FK_SuDungDichVu_DichVu FOREIGN KEY (MaDichVu) REFERENCES dbo.DichVu(MaDichVu)
);

CREATE TABLE dbo.ChiTietSuDungNV (
    MaSuDung bigint NOT NULL CONSTRAINT PK_ChiTietSuDungNV PRIMARY KEY,
    MaNVCT varchar(20) NOT NULL,
    MaDichVu varchar(20) NOT NULL,
    NgaySuDung date NOT NULL,
    SoLuot int NOT NULL,
    DonGiaApDung decimal(18,2) NOT NULL,
    CONSTRAINT FK_ChiTietSuDungNV_DichVu FOREIGN KEY (MaDichVu) REFERENCES dbo.DichVu(MaDichVu),
    CONSTRAINT UQ_ChiTietSuDungNV_Ngay UNIQUE (MaNVCT, MaDichVu, NgaySuDung)
);

CREATE TABLE dbo.PhanCongNVTN (
    MaNVTN varchar(20) NOT NULL,
    Thang tinyint NOT NULL,
    Nam smallint NOT NULL,
    MaDichVu varchar(20) NULL,
    MaBac varchar(20) NOT NULL,
    CONSTRAINT PK_PhanCongNVTN PRIMARY KEY (MaNVTN, Thang, Nam),
    CONSTRAINT FK_PhanCongNVTN_NhanVien FOREIGN KEY (MaNVTN) REFERENCES dbo.NhanVienToaNha(MaNVTN),
    CONSTRAINT FK_PhanCongNVTN_DichVu FOREIGN KEY (MaDichVu) REFERENCES dbo.DichVu(MaDichVu),
    CONSTRAINT FK_PhanCongNVTN_Bac FOREIGN KEY (MaBac) REFERENCES dbo.BacCongViec_TraCuu(MaBac)
);

CREATE TABLE dbo.ChiTietHoaDon (
    MaChiTiet bigint NOT NULL CONSTRAINT PK_ChiTietHoaDon PRIMARY KEY,
    MaHoaDon int NOT NULL,
    LoaiKhoan varchar(20) NOT NULL,
    MaVanPhong varchar(20) NULL,
    MaDichVu varchar(20) NULL,
    SoLuong decimal(12,2) NOT NULL,
    DonGiaApDung decimal(18,2) NOT NULL,
    TyLeNgay decimal(12,10) NOT NULL,
    CONSTRAINT FK_ChiTietHoaDon_HoaDon FOREIGN KEY (MaHoaDon) REFERENCES dbo.HoaDonThang(MaHoaDon),
    CONSTRAINT FK_ChiTietHoaDon_VanPhong FOREIGN KEY (MaVanPhong) REFERENCES dbo.VanPhong(MaVanPhong),
    CONSTRAINT FK_ChiTietHoaDon_DichVu FOREIGN KEY (MaDichVu) REFERENCES dbo.DichVu(MaDichVu)
);

-- ============================================================================
-- 5. CÁC MẢNH DỌC CỦA BẢNG LUONGTHANG (MỤC 7.4)
-- ============================================================================
-- Mảnh 1: LuongThang_Ky (Lưu khóa kỳ lương của nhân viên thuộc Site 2)
CREATE TABLE dbo.LuongThang_Ky (
    MaNVTN varchar(20) NOT NULL,
    Thang tinyint NOT NULL,
    Nam smallint NOT NULL,
    CONSTRAINT PK_LuongThang_Ky PRIMARY KEY (MaNVTN, Thang, Nam),
    CONSTRAINT FK_LuongThang_Ky_PhanCong FOREIGN KEY (MaNVTN, Thang, Nam)
        REFERENCES dbo.PhanCongNVTN(MaNVTN, Thang, Nam)
);

-- ============================================================================
-- 6. NẠP DỮ LIỆU MẪU CỦA MẢNH SITE 2 (TN02) KHỚP 100% PHẦN 3
-- ============================================================================
INSERT dbo.ThamSo(TenThamSo, GiaTri, MoTa) VALUES
    ('NGUONG_NGUOI', 10, N'Nguong so nguoi duong; gia dinh cho du lieu mau'),
    ('BUOC_NGUOI', 5, N'Buoc tang so nguoi; gia dinh cho du lieu mau'),
    ('NGUONG_DIEN_TICH', 100, N'Nguong dien tich m2; gia dinh cho du lieu mau'),
    ('BUOC_DIEN_TICH', 10, N'Buoc tang dien tich m2; gia dinh cho du lieu mau'),
    ('TY_LE_TANG_GIA', 0.05, N'Ty le tang phi; gia dinh cho du lieu mau');

INSERT dbo.ViTri(MaViTri, TenViTri, DonGiaThueM2) VALUES
    ('VT_TRONG', N'Khu ben trong', 200000),
    ('VT_MAT_TIEN', N'Mat tien', 250000);

INSERT dbo.LoaiDichVu(MaLoaiDV, TenLoai, KieuTinhPhi, CoTinhTheoNguoi, CoTinhTheoDienTich) VALUES
    ('AN_UONG', N'An uong', 'LUOT', 0, 0),
    ('GUI_XE', N'Gui xe', 'LUOT', 0, 0),
    ('VE_SINH', N'Ve sinh van phong', 'THANG', 1, 1);

INSERT dbo.BacCongViec_TraCuu(MaBac, TenBac) VALUES
    ('BAC_QL', N'Quan ly toa nha'),
    ('BAC_AN', N'Nhan vien nha an'),
    ('BAC_XE', N'Nhan vien bai xe');

INSERT dbo.CongTy_TraCuu(MaCongTy, TenCongTy, LinhVuc) VALUES
    ('CT01', N'Cong ty du lieu mau 1', N'Cong nghe thong tin'),
    ('CT02', N'Cong ty du lieu mau 2', N'Thuong mai'),
    ('CT03', N'Cong ty du lieu mau 3', N'Cong nghe thong tin'),
    ('CT04', N'Cong ty du lieu mau 4', N'Thuong mai'),
    ('CT05', N'Cong ty du lieu mau 5', N'Cong nghe thong tin'),
    ('CT06', N'Cong ty du lieu mau 6', N'Thuong mai');

-- Nạp mảnh ngang chính ToaNha_2 (1 dòng: TN02)
INSERT dbo.ToaNha(MaToaNha, TenToaNha, DiaChi, SoTang)
VALUES ('TN02', N'Toa nha mau 2', N'20 Duong Mo Phong, Ha Noi', 10);

-- Nạp mảnh ngang chính VanPhong_2 (4 dòng: VP05..VP08)
INSERT dbo.VanPhong(MaVanPhong, MaToaNha, MaViTri, Tang, DienTich) VALUES
    ('VP05', 'TN02', 'VT_TRONG', 1, 80),
    ('VP06', 'TN02', 'VT_MAT_TIEN', 2, 120),
    ('VP07', 'TN02', 'VT_TRONG', 3, 80),
    ('VP08', 'TN02', 'VT_MAT_TIEN', 4, 120);

-- Nạp mảnh ngang dẫn xuất HopDongThue_2 (4 dòng: HD05..HD08)
INSERT dbo.HopDongThue(MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc) VALUES
    ('HD05', 'CT03', 'VP05', '20260701', '20270630'),
    ('HD06', 'CT03', 'VP06', '20260701', '20270630'),
    ('HD07', 'CT04', 'VP07', '20260701', '20270630'),
    ('HD08', 'CT04', 'VP08', '20260701', '20270630');

-- Nạp mảnh ngang chính DichVu_2 (3 dòng)
INSERT dbo.DichVu(MaDichVu, MaToaNha, MaLoaiDV, TenDichVu, DonGiaCoBan) VALUES
    ('AN02', 'TN02', 'AN_UONG', N'An trua - Toa nha mau 2', 35000),
    ('XE02', 'TN02', 'GUI_XE', N'Gui xe may - Toa nha mau 2', 5000),
    ('VS02', 'TN02', 'VE_SINH', N'Ve sinh - Toa nha mau 2', 1500000);

-- Nạp mảnh ngang dẫn xuất SuDungDichVu_2 (6 dòng)
INSERT dbo.SuDungDichVu(MaCongTy, MaDichVu, NgayBatDau, NgayKetThuc)
SELECT DISTINCT hd.MaCongTy, dv.MaDichVu, '20260701', '20270630'
FROM dbo.HopDongThue AS hd
CROSS JOIN dbo.DichVu AS dv;

-- Tạo bảng tạm sinh dữ liệu nhật ký 2 tháng 08-09/2026 (61 ngày)
CREATE TABLE #So (So int NOT NULL PRIMARY KEY);
INSERT #So(So)
SELECT chuc.So * 10 + donvi.So
FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS chuc(So)
CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS donvi(So);

CREATE TABLE #Ngay (Ngay date NOT NULL PRIMARY KEY);
INSERT #Ngay(Ngay)
SELECT DATEADD(day, So, CONVERT(date, '20260801'))
FROM #So WHERE So < DATEDIFF(day, '20260801', '20261001');

-- Nạp mảnh ngang dẫn xuất ChiTietSuDungNV_2 (2.440 dòng của Site 2: 20 nhân viên x 2 dịch vụ lượt x 61 ngày)
INSERT dbo.ChiTietSuDungNV(MaSuDung, MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung)
SELECT
    2440 + ROW_NUMBER() OVER (ORDER BY nv.So, dv.MaDichVu, ngay.Ngay) AS MaSuDung,
    CONCAT('NVCT', RIGHT(CONCAT('000', nv.So), 3)) AS MaNVCT,
    dv.MaDichVu,
    ngay.Ngay,
    1 AS SoLuot,
    dv.DonGiaCoBan
FROM #So AS nv
CROSS JOIN dbo.DichVu AS dv
CROSS JOIN #Ngay AS ngay
WHERE nv.So BETWEEN 21 AND 40
  AND dv.MaLoaiDV IN ('AN_UONG', 'GUI_XE');

-- Nạp mảnh ngang chính NhanVienToaNha_2 (3 dòng)
INSERT dbo.NhanVienToaNha(MaNVTN, MaToaNha, MaQuanLy, LoaiNV, HoTen, GioiTinh, NgaySinh, DienThoai, Email, NgayVaoLam) VALUES
    ('QL02', 'TN02', NULL, 'QUAN_LY', N'Quan ly mau TN02', 'M', '19850101', NULL, 'manager02@example.com', '20260101'),
    ('NVAN02', 'TN02', 'QL02', 'DICH_VU', N'Nhan vien mau AN02', 'F', '19920101', NULL, 'staffAN02@example.com', '20260101'),
    ('NVXE02', 'TN02', 'QL02', 'DICH_VU', N'Nhan vien mau XE02', 'M', '19920101', NULL, 'staffXE02@example.com', '20260101');

-- Nạp mảnh ngang dẫn xuất PhanCongNVTN_2 (6 dòng cho tháng 8 và 9/2026)
INSERT dbo.PhanCongNVTN(MaNVTN, Thang, Nam, MaDichVu, MaBac) VALUES
    ('QL02', 8, 2026, NULL, 'BAC_QL'),
    ('NVAN02', 8, 2026, 'AN02', 'BAC_AN'),
    ('NVXE02', 8, 2026, 'XE02', 'BAC_XE'),
    ('QL02', 9, 2026, NULL, 'BAC_QL'),
    ('NVAN02', 9, 2026, 'AN02', 'BAC_AN'),
    ('NVXE02', 9, 2026, 'XE02', 'BAC_XE');

-- Nạp mảnh dọc LuongThang_Ky tại Site 2 (6 dòng khóa kỳ lương)
INSERT dbo.LuongThang_Ky(MaNVTN, Thang, Nam)
SELECT MaNVTN, Thang, Nam FROM dbo.PhanCongNVTN;

-- Nạp mảnh HoaDonThang_2 (4 hóa đơn của TN02)
INSERT dbo.HoaDonThang(MaHoaDon, MaCongTy, MaToaNha, Thang, Nam, NgayLap, TrangThai, NgayThanhToan, NguoiThu) VALUES
    (5, 'CT03', 'TN02', 8, 2026, '20260831', 'DA_THANH_TOAN', '20260905', N'Thu ngan mau'),
    (6, 'CT03', 'TN02', 9, 2026, '20260930', 'CHUA_THANH_TOAN', NULL, NULL),
    (7, 'CT04', 'TN02', 8, 2026, '20260831', 'DA_THANH_TOAN', '20260905', N'Thu ngan mau'),
    (8, 'CT04', 'TN02', 9, 2026, '20260930', 'CHUA_THANH_TOAN', NULL, NULL);

-- Nạp mảnh dẫn xuất ChiTietHoaDon_2 (20 dòng chi tiết hóa đơn của TN02)
;WITH DongChiTiet AS (
    SELECT hoadon.MaHoaDon, 'THUE_VAN_PHONG' AS LoaiKhoan, vp.MaVanPhong, CAST(NULL AS varchar(20)) AS MaDichVu,
        CAST(vp.DienTich AS decimal(12,2)) AS SoLuong, vitri.DonGiaThueM2 AS DonGiaApDung, CAST(1 AS decimal(12,10)) AS TyLeNgay
    FROM dbo.HoaDonThang AS hoadon
    JOIN dbo.HopDongThue AS hd ON hd.MaCongTy = hoadon.MaCongTy
    JOIN dbo.VanPhong AS vp ON vp.MaVanPhong = hd.MaVanPhong AND vp.MaToaNha = hoadon.MaToaNha
    JOIN dbo.ViTri AS vitri ON vitri.MaViTri = vp.MaViTri
    UNION ALL
    SELECT hoadon.MaHoaDon, 'DICH_VU_THANG', NULL, 'VS02',
        CAST(1 AS decimal(12,2)), CAST(2250000 AS decimal(18,2)), CAST(1 AS decimal(12,10))
    FROM dbo.HoaDonThang AS hoadon
    UNION ALL
    SELECT hoadon.MaHoaDon, 'DICH_VU_LUOT', NULL, 'AN02',
        CAST(CASE WHEN hoadon.Thang = 8 THEN 310 ELSE 300 END AS decimal(12,2)), CAST(35000 AS decimal(18,2)), CAST(1 AS decimal(12,10))
    FROM dbo.HoaDonThang AS hoadon
    UNION ALL
    SELECT hoadon.MaHoaDon, 'DICH_VU_LUOT', NULL, 'XE02',
        CAST(CASE WHEN hoadon.Thang = 8 THEN 310 ELSE 300 END AS decimal(12,2)), CAST(5000 AS decimal(18,2)), CAST(1 AS decimal(12,10))
    FROM dbo.HoaDonThang AS hoadon
)
INSERT dbo.ChiTietHoaDon(MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
SELECT
    20 + ROW_NUMBER() OVER (ORDER BY MaHoaDon, LoaiKhoan, ISNULL(MaVanPhong, MaDichVu)),
    MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay
FROM DongChiTiet;

-- Nạp mảnh ngang chính ChiPhiVanHanh_2 (6 dòng)
INSERT dbo.ChiPhiVanHanh(MaChiPhi, MaToaNha, Thang, Nam, LoaiChiPhi, SoTien, MoTa) VALUES
    (7, 'TN02', 8, 2026, N'Dien nuoc', 12000000, N'Chi phi mau thang 8/2026'),
    (8, 'TN02', 8, 2026, N'Bao tri', 5000000, N'Chi phi mau thang 8/2026'),
    (9, 'TN02', 8, 2026, N'Vat tu', 3000000, N'Chi phi mau thang 8/2026'),
    (10, 'TN02', 9, 2026, N'Dien nuoc', 12000000, N'Chi phi mau thang 9/2026'),
    (11, 'TN02', 9, 2026, N'Bao tri', 5000000, N'Chi phi mau thang 9/2026'),
    (12, 'TN02', 9, 2026, N'Vat tu', 3000000, N'Chi phi mau thang 9/2026');

DROP TABLE #Ngay;
DROP TABLE #So;

COMMIT TRANSACTION;
GO

-- View tính thành tiền dòng hóa đơn chuẩn BCNF tại Site 2
CREATE VIEW dbo.v_ChiTietHoaDon
AS
SELECT MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay,
    ROUND(SoLuong * DonGiaApDung * TyLeNgay, 2) AS SoTien
FROM dbo.ChiTietHoaDon;
GO

-- Hiển thị thống kê số lượng bản ghi đã nạp tại Site 2 (QLToaNha_Site2)
SELECT
    'QLToaNha_Site2' AS TenDatabase,
    'TN02' AS MaToaNha,
    (SELECT COUNT(*) FROM dbo.ToaNha) AS SoToaNha,
    (SELECT COUNT(*) FROM dbo.VanPhong) AS SoVanPhong,
    (SELECT COUNT(*) FROM dbo.HopDongThue) AS SoHopDong,
    (SELECT COUNT(*) FROM dbo.HoaDonThang) AS SoHoaDon,
    (SELECT COUNT(*) FROM dbo.ChiTietHoaDon) AS SoChiTietHD,
    (SELECT COUNT(*) FROM dbo.ChiTietSuDungNV) AS SoNhatKyDichVu,
    (SELECT COUNT(*) FROM dbo.LuongThang_Ky) AS SoKyLuongSite;
GO
