USE master;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_ID(N'QLToaNha_BCNF') IS NULL
    EXEC(N'CREATE DATABASE QLToaNha_BCNF');
GO
USE QLToaNha_BCNF;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF EXISTS (SELECT 1 FROM sys.tables WHERE is_ms_shipped = 0)
    THROW 51000, N'Database da co bang. Khong ghi de; hay dung database moi.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    CREATE TABLE dbo.ThamSo (
        TenThamSo varchar(50) NOT NULL CONSTRAINT PK_ThamSo PRIMARY KEY,
        GiaTri decimal(18,6) NOT NULL,
        MoTa nvarchar(300) NOT NULL,
        CONSTRAINT CK_ThamSo_GiaTri CHECK (GiaTri >= 0),
        CONSTRAINT CK_ThamSo_SoNguoi CHECK (
            TenThamSo NOT IN ('NGUONG_NGUOI', 'BUOC_NGUOI')
            OR (GiaTri > 0 AND GiaTri = FLOOR(GiaTri))),
        CONSTRAINT CK_ThamSo_DienTich CHECK (
            TenThamSo NOT IN ('NGUONG_DIEN_TICH', 'BUOC_DIEN_TICH') OR GiaTri > 0),
        CONSTRAINT CK_ThamSo_TyLe CHECK (TenThamSo <> 'TY_LE_TANG_GIA' OR GiaTri <= 1)
    );

    CREATE TABLE dbo.ViTri (
        MaViTri varchar(20) NOT NULL CONSTRAINT PK_ViTri PRIMARY KEY,
        TenViTri nvarchar(100) NOT NULL CONSTRAINT UQ_ViTri_Ten UNIQUE,
        DonGiaThueM2 decimal(18,2) NOT NULL,
        CONSTRAINT CK_ViTri_DonGia CHECK (DonGiaThueM2 > 0)
    );

    CREATE TABLE dbo.LoaiDichVu (
        MaLoaiDV varchar(20) NOT NULL CONSTRAINT PK_LoaiDichVu PRIMARY KEY,
        TenLoai nvarchar(100) NOT NULL CONSTRAINT UQ_LoaiDichVu_Ten UNIQUE,
        KieuTinhPhi varchar(10) NOT NULL,
        CoTinhTheoNguoi bit NOT NULL CONSTRAINT DF_LoaiDichVu_Nguoi DEFAULT (0),
        CoTinhTheoDienTich bit NOT NULL CONSTRAINT DF_LoaiDichVu_DienTich DEFAULT (0),
        CONSTRAINT CK_LoaiDichVu_Kieu CHECK (KieuTinhPhi IN ('THANG', 'LUOT')),
        CONSTRAINT CK_LoaiDichVu_CachTinh CHECK (
            KieuTinhPhi = 'THANG' OR (CoTinhTheoNguoi = 0 AND CoTinhTheoDienTich = 0))
    );

    CREATE TABLE dbo.BacCongViec (
        MaBac varchar(20) NOT NULL CONSTRAINT PK_BacCongViec PRIMARY KEY,
        TenBac nvarchar(100) NOT NULL CONSTRAINT UQ_BacCongViec_Ten UNIQUE,
        LuongCoBan decimal(18,2) NOT NULL,
        HeSoDoanhThu decimal(9,6) NOT NULL CONSTRAINT DF_BacCongViec_HeSo DEFAULT (0),
        CONSTRAINT CK_BacCongViec_Luong CHECK (LuongCoBan > 0),
        CONSTRAINT CK_BacCongViec_HeSo CHECK (HeSoDoanhThu BETWEEN 0 AND 1)
    );

    CREATE TABLE dbo.ToaNha (
        MaToaNha varchar(20) NOT NULL CONSTRAINT PK_ToaNha PRIMARY KEY,
        TenToaNha nvarchar(150) NOT NULL,
        DiaChi nvarchar(300) NOT NULL,
        SoTang smallint NOT NULL,
        CONSTRAINT CK_ToaNha_SoTang CHECK (SoTang > 0)
    );

    CREATE TABLE dbo.CongTy (
        MaCongTy varchar(20) NOT NULL CONSTRAINT PK_CongTy PRIMARY KEY,
        TenCongTy nvarchar(200) NOT NULL,
        MaSoThue varchar(14) NOT NULL CONSTRAINT UQ_CongTy_MaSoThue UNIQUE,
        DiaChi nvarchar(300) NOT NULL,
        DienThoai varchar(20) NULL,
        Email varchar(254) NULL,
        LinhVuc nvarchar(100) NOT NULL,
        CONSTRAINT CK_CongTy_MST CHECK (
            (DATALENGTH(MaSoThue) = 10
                AND MaSoThue COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9]%')
            OR (DATALENGTH(MaSoThue) = 14 AND SUBSTRING(MaSoThue, 11, 1) = '-'
                AND LEFT(MaSoThue, 10) COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9]%'
                AND RIGHT(MaSoThue, 3) COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9]%'))
    );

    CREATE TABLE dbo.VanPhong (
        MaVanPhong varchar(20) NOT NULL CONSTRAINT PK_VanPhong PRIMARY KEY,
        MaToaNha varchar(20) NOT NULL,
        MaViTri varchar(20) NOT NULL,
        Tang smallint NOT NULL,
        DienTich decimal(10,2) NOT NULL,
        CONSTRAINT FK_VanPhong_ToaNha FOREIGN KEY (MaToaNha) REFERENCES dbo.ToaNha(MaToaNha),
        CONSTRAINT FK_VanPhong_ViTri FOREIGN KEY (MaViTri) REFERENCES dbo.ViTri(MaViTri),
        CONSTRAINT CK_VanPhong_Tang CHECK (Tang > 0),
        CONSTRAINT CK_VanPhong_DienTich CHECK (DienTich > 0)
    );

    CREATE TABLE dbo.NhanVienCongTy (
        MaNVCT varchar(20) NOT NULL CONSTRAINT PK_NhanVienCongTy PRIMARY KEY,
        MaCongTy varchar(20) NOT NULL,
        HoTen nvarchar(150) NOT NULL,
        GioiTinh char(1) NOT NULL,
        NgaySinh date NOT NULL,
        DienThoai varchar(20) NULL,
        Email varchar(254) NULL,
        ChucVu nvarchar(100) NOT NULL,
        NgayVaoLam date NOT NULL,
        NgayNghiViec date NULL,
        CONSTRAINT FK_NhanVienCongTy_CongTy FOREIGN KEY (MaCongTy) REFERENCES dbo.CongTy(MaCongTy),
        CONSTRAINT CK_NhanVienCongTy_GioiTinh CHECK (GioiTinh IN ('M', 'F', 'O')),
        CONSTRAINT CK_NhanVienCongTy_NgaySinh CHECK (NgaySinh < NgayVaoLam),
        -- TV6 sửa: ngày nghỉ có thể trùng ngày vào làm theo quy ước dùng ngày biên bao gồm.
        CONSTRAINT CK_NhanVienCongTy_NgayNghi CHECK (NgayNghiViec IS NULL OR NgayNghiViec >= NgayVaoLam)
    );

    CREATE TABLE dbo.DichVu (
        MaDichVu varchar(20) NOT NULL CONSTRAINT PK_DichVu PRIMARY KEY,
        MaToaNha varchar(20) NOT NULL,
        MaLoaiDV varchar(20) NOT NULL,
        TenDichVu nvarchar(120) NOT NULL,
        DonGiaCoBan decimal(18,2) NOT NULL,
        CONSTRAINT FK_DichVu_ToaNha FOREIGN KEY (MaToaNha) REFERENCES dbo.ToaNha(MaToaNha),
        CONSTRAINT FK_DichVu_LoaiDichVu FOREIGN KEY (MaLoaiDV) REFERENCES dbo.LoaiDichVu(MaLoaiDV),
        -- TV6 sửa: thống nhất điều kiện đơn giá cơ bản với form và API.
        CONSTRAINT CK_DichVu_DonGia CHECK (DonGiaCoBan > 0)
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
        CONSTRAINT CK_NhanVienToaNha_Loai CHECK (LoaiNV IN ('QUAN_LY', 'DICH_VU')),
        CONSTRAINT CK_NhanVienToaNha_QuanLy CHECK (
            (LoaiNV = 'QUAN_LY' AND MaQuanLy IS NULL)
            OR (LoaiNV = 'DICH_VU' AND MaQuanLy IS NOT NULL AND MaQuanLy <> MaNVTN)),
        CONSTRAINT CK_NhanVienToaNha_GioiTinh CHECK (GioiTinh IN ('M', 'F', 'O')),
        CONSTRAINT CK_NhanVienToaNha_Ngay CHECK (NgaySinh < NgayVaoLam)
    );

    CREATE TABLE dbo.HoaDonThang (
        MaHoaDon int IDENTITY(1,1) NOT NULL CONSTRAINT PK_HoaDonThang PRIMARY KEY,
        MaCongTy varchar(20) NOT NULL,
        MaToaNha varchar(20) NOT NULL,
        Thang tinyint NOT NULL,
        Nam smallint NOT NULL,
        NgayLap date NOT NULL CONSTRAINT DF_HoaDonThang_NgayLap DEFAULT (CONVERT(date, GETDATE())),
        TrangThai varchar(20) NOT NULL CONSTRAINT DF_HoaDon_TrangThai DEFAULT ('CHUA_THANH_TOAN'),
        NgayThanhToan date NULL,
        NguoiThu nvarchar(100) NULL,
        CONSTRAINT CK_HoaDonThang_ThanhToan CHECK (
            (TrangThai = 'CHUA_THANH_TOAN' AND NgayThanhToan IS NULL AND NguoiThu IS NULL)
            OR (TrangThai = 'DA_THANH_TOAN' AND NgayThanhToan IS NOT NULL AND NgayThanhToan >= NgayLap
                AND (NguoiThu IS NULL OR LEN(LTRIM(RTRIM(NguoiThu))) > 0))),
        CONSTRAINT FK_HoaDonThang_CongTy FOREIGN KEY (MaCongTy) REFERENCES dbo.CongTy(MaCongTy),
        CONSTRAINT FK_HoaDonThang_ToaNha FOREIGN KEY (MaToaNha) REFERENCES dbo.ToaNha(MaToaNha),
        CONSTRAINT UQ_HoaDonThang_Ky UNIQUE (MaCongTy, MaToaNha, Thang, Nam),
        CONSTRAINT CK_HoaDonThang_Thang CHECK (Thang BETWEEN 1 AND 12),
        CONSTRAINT CK_HoaDonThang_Nam CHECK (Nam BETWEEN 1900 AND 9999)
    );

    CREATE TABLE dbo.ChiPhiVanHanh (
        MaChiPhi bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ChiPhiVanHanh PRIMARY KEY,
        MaToaNha varchar(20) NOT NULL,
        Thang tinyint NOT NULL,
        Nam smallint NOT NULL,
        LoaiChiPhi nvarchar(100) NOT NULL,
        SoTien decimal(18,2) NOT NULL,
        MoTa nvarchar(300) NOT NULL CONSTRAINT DF_ChiPhiVanHanh_MoTa DEFAULT (N''),
        CONSTRAINT FK_ChiPhiVanHanh_ToaNha FOREIGN KEY (MaToaNha) REFERENCES dbo.ToaNha(MaToaNha),
        CONSTRAINT CK_ChiPhiVanHanh_Thang CHECK (Thang BETWEEN 1 AND 12),
        CONSTRAINT CK_ChiPhiVanHanh_Nam CHECK (Nam BETWEEN 1900 AND 9999),
        CONSTRAINT CK_ChiPhiVanHanh_SoTien CHECK (SoTien > 0)
    );

    CREATE TABLE dbo.HopDongThue (
        MaHopDong varchar(20) NOT NULL CONSTRAINT PK_HopDongThue PRIMARY KEY,
        MaCongTy varchar(20) NOT NULL,
        MaVanPhong varchar(20) NOT NULL,
        NgayBatDau date NOT NULL,
        NgayKetThuc date NULL,
        CONSTRAINT FK_HopDongThue_CongTy FOREIGN KEY (MaCongTy) REFERENCES dbo.CongTy(MaCongTy),
        CONSTRAINT FK_HopDongThue_VanPhong FOREIGN KEY (MaVanPhong) REFERENCES dbo.VanPhong(MaVanPhong),
        -- TV6 sửa: cho phép hợp đồng có hiệu lực đúng một ngày.
        CONSTRAINT CK_HopDongThue_Ngay CHECK (NgayKetThuc IS NULL OR NgayKetThuc >= NgayBatDau)
    );

    CREATE TABLE dbo.SuDungDichVu (
        MaCongTy varchar(20) NOT NULL,
        MaDichVu varchar(20) NOT NULL,
        NgayBatDau date NOT NULL,
        NgayKetThuc date NULL,
        CONSTRAINT PK_SuDungDichVu PRIMARY KEY (MaCongTy, MaDichVu, NgayBatDau),
        CONSTRAINT FK_SuDungDichVu_CongTy FOREIGN KEY (MaCongTy) REFERENCES dbo.CongTy(MaCongTy),
        CONSTRAINT FK_SuDungDichVu_DichVu FOREIGN KEY (MaDichVu) REFERENCES dbo.DichVu(MaDichVu),
        -- TV6 sửa: đăng ký dịch vụ một ngày cũng hợp lệ.
        CONSTRAINT CK_SuDungDichVu_Ngay CHECK (NgayKetThuc IS NULL OR NgayKetThuc >= NgayBatDau)
    );

    CREATE TABLE dbo.ChiTietSuDungNV (
        MaSuDung bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ChiTietSuDungNV PRIMARY KEY,
        MaNVCT varchar(20) NOT NULL,
        MaDichVu varchar(20) NOT NULL,
        NgaySuDung date NOT NULL CONSTRAINT DF_ChiTietSuDungNV_Ngay DEFAULT (CONVERT(date, GETDATE())),
        SoLuot int NOT NULL CONSTRAINT DF_ChiTietSuDungNV_SoLuot DEFAULT (1),
        DonGiaApDung decimal(18,2) NOT NULL,
        CONSTRAINT FK_ChiTietSuDungNV_NhanVien FOREIGN KEY (MaNVCT) REFERENCES dbo.NhanVienCongTy(MaNVCT),
        CONSTRAINT FK_ChiTietSuDungNV_DichVu FOREIGN KEY (MaDichVu) REFERENCES dbo.DichVu(MaDichVu),
        CONSTRAINT UQ_ChiTietSuDungNV_Ngay UNIQUE (MaNVCT, MaDichVu, NgaySuDung),
        CONSTRAINT CK_ChiTietSuDungNV_SoLuot CHECK (SoLuot > 0),
        CONSTRAINT CK_ChiTietSuDungNV_DonGia CHECK (DonGiaApDung >= 0)
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
        CONSTRAINT FK_PhanCongNVTN_Bac FOREIGN KEY (MaBac) REFERENCES dbo.BacCongViec(MaBac),
        CONSTRAINT CK_PhanCongNVTN_Thang CHECK (Thang BETWEEN 1 AND 12),
        CONSTRAINT CK_PhanCongNVTN_Nam CHECK (Nam BETWEEN 1900 AND 9999)
    );

    CREATE TABLE dbo.ChiTietHoaDon (
        MaChiTiet bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ChiTietHoaDon PRIMARY KEY,
        MaHoaDon int NOT NULL,
        LoaiKhoan varchar(20) NOT NULL,
        MaVanPhong varchar(20) NULL,
        MaDichVu varchar(20) NULL,
        SoLuong decimal(12,2) NOT NULL CONSTRAINT DF_ChiTietHoaDon_SoLuong DEFAULT (1),
        DonGiaApDung decimal(18,2) NOT NULL,
        TyLeNgay decimal(12,10) NOT NULL CONSTRAINT DF_ChiTietHoaDon_TyLe DEFAULT (1),
        CONSTRAINT FK_ChiTietHoaDon_HoaDon FOREIGN KEY (MaHoaDon) REFERENCES dbo.HoaDonThang(MaHoaDon),
        CONSTRAINT FK_ChiTietHoaDon_VanPhong FOREIGN KEY (MaVanPhong) REFERENCES dbo.VanPhong(MaVanPhong),
        CONSTRAINT FK_ChiTietHoaDon_DichVu FOREIGN KEY (MaDichVu) REFERENCES dbo.DichVu(MaDichVu),
        CONSTRAINT CK_ChiTietHoaDon_Loai CHECK (
            (LoaiKhoan = 'THUE_VAN_PHONG' AND MaVanPhong IS NOT NULL AND MaDichVu IS NULL)
            OR (LoaiKhoan IN ('DICH_VU_THANG', 'DICH_VU_LUOT') AND MaVanPhong IS NULL AND MaDichVu IS NOT NULL)),
        CONSTRAINT CK_ChiTietHoaDon_SoLuong CHECK (SoLuong > 0),
        CONSTRAINT CK_ChiTietHoaDon_DonGia CHECK (DonGiaApDung >= 0),
        CONSTRAINT CK_ChiTietHoaDon_TyLe CHECK (TyLeNgay > 0 AND TyLeNgay <= 1)
    );

    CREATE TABLE dbo.LuongThang (
        MaNVTN varchar(20) NOT NULL,
        Thang tinyint NOT NULL,
        Nam smallint NOT NULL,
        LuongCoBan decimal(18,2) NOT NULL,
        TienThuong decimal(18,2) NOT NULL CONSTRAINT DF_LuongThang_Thuong DEFAULT (0),
        CONSTRAINT PK_LuongThang PRIMARY KEY (MaNVTN, Thang, Nam),
        CONSTRAINT FK_LuongThang_PhanCong FOREIGN KEY (MaNVTN, Thang, Nam)
            REFERENCES dbo.PhanCongNVTN(MaNVTN, Thang, Nam),
        CONSTRAINT CK_LuongThang_Thang CHECK (Thang BETWEEN 1 AND 12),
        CONSTRAINT CK_LuongThang_Nam CHECK (Nam BETWEEN 1900 AND 9999),
        CONSTRAINT CK_LuongThang_Tien CHECK (LuongCoBan > 0 AND TienThuong >= 0)
    );

    CREATE INDEX IX_VanPhong_ToaNha ON dbo.VanPhong(MaToaNha);
    CREATE INDEX IX_VanPhong_ViTri ON dbo.VanPhong(MaViTri);
    CREATE INDEX IX_HopDongThue_VanPhong_Ngay ON dbo.HopDongThue(MaVanPhong, NgayBatDau, NgayKetThuc);
    CREATE INDEX IX_HopDongThue_CongTy ON dbo.HopDongThue(MaCongTy);
    CREATE INDEX IX_NhanVienCongTy_CongTy ON dbo.NhanVienCongTy(MaCongTy);
    CREATE INDEX IX_DichVu_Loai ON dbo.DichVu(MaLoaiDV);
    CREATE INDEX IX_SuDungDichVu_DichVu ON dbo.SuDungDichVu(MaDichVu, NgayBatDau, NgayKetThuc);
    CREATE INDEX IX_ChiTietSuDungNV_DichVu_Ngay ON dbo.ChiTietSuDungNV(MaDichVu, NgaySuDung) INCLUDE (MaNVCT, SoLuot, DonGiaApDung);
    CREATE INDEX IX_NhanVienToaNha_ToaNha ON dbo.NhanVienToaNha(MaToaNha);
    CREATE INDEX IX_NhanVienToaNha_QuanLy ON dbo.NhanVienToaNha(MaQuanLy);
    CREATE INDEX IX_PhanCongNVTN_DichVu ON dbo.PhanCongNVTN(MaDichVu);
    CREATE INDEX IX_PhanCongNVTN_Bac ON dbo.PhanCongNVTN(MaBac);
    CREATE INDEX IX_HoaDonThang_ToaNha_Ky ON dbo.HoaDonThang(MaToaNha, Nam, Thang);
    CREATE INDEX IX_ChiTietHoaDon_HoaDon ON dbo.ChiTietHoaDon(MaHoaDon);
    CREATE INDEX IX_ChiTietHoaDon_VanPhong ON dbo.ChiTietHoaDon(MaVanPhong);
    CREATE INDEX IX_ChiTietHoaDon_DichVu ON dbo.ChiTietHoaDon(MaDichVu);
    CREATE INDEX IX_ChiPhiVanHanh_ToaNha_Ky ON dbo.ChiPhiVanHanh(MaToaNha, Nam, Thang);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

GO
CREATE VIEW dbo.V_ChiTietHoaDon
AS
SELECT MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay,
    ROUND(SoLuong * DonGiaApDung * TyLeNgay, 2) AS SoTien
FROM dbo.ChiTietHoaDon;
GO

SELECT N'Schema created' AS KetQua,
    (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0) AS SoBang,
    (SELECT COUNT(*) FROM sys.foreign_keys) AS SoFK;
GO
