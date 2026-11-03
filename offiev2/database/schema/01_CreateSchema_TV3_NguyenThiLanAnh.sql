/* ============================================================================
   TV3 - DDL 18 bang BCNF (ban MySQL 8.0, chuyen tu T-SQL SQL Server)
   Yeu cau : MySQL 8.0.16 tro len (CHECK constraint duoc thi hanh).
   Chay    : mysql -u root -p < 01_CreateSchema_TV3_NguyenThiLanAnh.sql
   Ghi chu : Khong ghi de. Neu database QLToaNha_BCNF da ton tai, lenh CREATE DATABASE
             se loi, dung nhu quy tac "khong ghi de" cua ban SQL Server.
   ============================================================================ */
CREATE DATABASE QLToaNha_BCNF CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_as_ci;
USE QLToaNha_BCNF;

CREATE TABLE ThamSo (
    TenThamSo VARCHAR(50) NOT NULL,
    GiaTri DECIMAL(18,6) NOT NULL,
    MoTa VARCHAR(300) NOT NULL,
    CONSTRAINT PK_ThamSo PRIMARY KEY (TenThamSo),
    CONSTRAINT CK_ThamSo_GiaTri CHECK (GiaTri >= 0),
    CONSTRAINT CK_ThamSo_SoNguoi CHECK (
        TenThamSo NOT IN ('NGUONG_NGUOI', 'BUOC_NGUOI')
        OR (GiaTri > 0 AND GiaTri = FLOOR(GiaTri))),
    CONSTRAINT CK_ThamSo_DienTich CHECK (
        TenThamSo NOT IN ('NGUONG_DIEN_TICH', 'BUOC_DIEN_TICH') OR GiaTri > 0),
    CONSTRAINT CK_ThamSo_TyLe CHECK (TenThamSo <> 'TY_LE_TANG_GIA' OR GiaTri <= 1)
) ENGINE=InnoDB;

CREATE TABLE ViTri (
    MaViTri VARCHAR(20) NOT NULL,
    TenViTri VARCHAR(100) NOT NULL,
    DonGiaThueM2 DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_ViTri PRIMARY KEY (MaViTri),
    CONSTRAINT UQ_ViTri_Ten UNIQUE (TenViTri),
    CONSTRAINT CK_ViTri_DonGia CHECK (DonGiaThueM2 > 0)
) ENGINE=InnoDB;

CREATE TABLE LoaiDichVu (
    MaLoaiDV VARCHAR(20) NOT NULL,
    TenLoai VARCHAR(100) NOT NULL,
    KieuTinhPhi VARCHAR(10) NOT NULL,
    CoTinhTheoNguoi TINYINT(1) NOT NULL DEFAULT 0,
    CoTinhTheoDienTich TINYINT(1) NOT NULL DEFAULT 0,
    CONSTRAINT PK_LoaiDichVu PRIMARY KEY (MaLoaiDV),
    CONSTRAINT UQ_LoaiDichVu_Ten UNIQUE (TenLoai),
    CONSTRAINT CK_LoaiDichVu_Kieu CHECK (KieuTinhPhi IN ('THANG', 'LUOT')),
    CONSTRAINT CK_LoaiDichVu_CachTinh CHECK (
        KieuTinhPhi = 'THANG' OR (CoTinhTheoNguoi = 0 AND CoTinhTheoDienTich = 0)),
    CONSTRAINT CK_LoaiDichVu_Bit CHECK (CoTinhTheoNguoi IN (0, 1) AND CoTinhTheoDienTich IN (0, 1))
) ENGINE=InnoDB;

CREATE TABLE BacCongViec (
    MaBac VARCHAR(20) NOT NULL,
    TenBac VARCHAR(100) NOT NULL,
    LuongCoBan DECIMAL(18,2) NOT NULL,
    HeSoDoanhThu DECIMAL(9,6) NOT NULL DEFAULT 0,
    CONSTRAINT PK_BacCongViec PRIMARY KEY (MaBac),
    CONSTRAINT UQ_BacCongViec_Ten UNIQUE (TenBac),
    CONSTRAINT CK_BacCongViec_Luong CHECK (LuongCoBan > 0),
    CONSTRAINT CK_BacCongViec_HeSo CHECK (HeSoDoanhThu BETWEEN 0 AND 1)
) ENGINE=InnoDB;

CREATE TABLE ToaNha (
    MaToaNha VARCHAR(20) NOT NULL,
    TenToaNha VARCHAR(150) NOT NULL,
    DiaChi VARCHAR(300) NOT NULL,
    SoTang SMALLINT NOT NULL,
    CONSTRAINT PK_ToaNha PRIMARY KEY (MaToaNha),
    CONSTRAINT CK_ToaNha_SoTang CHECK (SoTang > 0)
) ENGINE=InnoDB;

CREATE TABLE CongTy (
    MaCongTy VARCHAR(20) NOT NULL,
    TenCongTy VARCHAR(200) NOT NULL,
    MaSoThue VARCHAR(14) NOT NULL,
    DiaChi VARCHAR(300) NOT NULL,
    DienThoai VARCHAR(20) NULL,
    Email VARCHAR(254) NULL,
    LinhVuc VARCHAR(100) NOT NULL,
    CONSTRAINT PK_CongTy PRIMARY KEY (MaCongTy),
    CONSTRAINT UQ_CongTy_MaSoThue UNIQUE (MaSoThue),
    -- MST: 10 chu so, hoac 10 chu so + '-' + 3 chu so (chi nhanh)
    CONSTRAINT CK_CongTy_MST CHECK (MaSoThue REGEXP '^[0-9]{10}(-[0-9]{3})?$')
) ENGINE=InnoDB;

CREATE TABLE VanPhong (
    MaVanPhong VARCHAR(20) NOT NULL,
    MaToaNha VARCHAR(20) NOT NULL,
    MaViTri VARCHAR(20) NOT NULL,
    Tang SMALLINT NOT NULL,
    DienTich DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_VanPhong PRIMARY KEY (MaVanPhong),
    CONSTRAINT FK_VanPhong_ToaNha FOREIGN KEY (MaToaNha) REFERENCES ToaNha(MaToaNha),
    CONSTRAINT FK_VanPhong_ViTri FOREIGN KEY (MaViTri) REFERENCES ViTri(MaViTri),
    CONSTRAINT CK_VanPhong_Tang CHECK (Tang > 0),
    CONSTRAINT CK_VanPhong_DienTich CHECK (DienTich > 0)
) ENGINE=InnoDB;

CREATE TABLE NhanVienCongTy (
    MaNVCT VARCHAR(20) NOT NULL,
    MaCongTy VARCHAR(20) NOT NULL,
    HoTen VARCHAR(150) NOT NULL,
    GioiTinh CHAR(1) NOT NULL,
    NgaySinh DATE NOT NULL,
    DienThoai VARCHAR(20) NULL,
    Email VARCHAR(254) NULL,
    ChucVu VARCHAR(100) NOT NULL,
    NgayVaoLam DATE NOT NULL,
    NgayNghiViec DATE NULL,
    CONSTRAINT PK_NhanVienCongTy PRIMARY KEY (MaNVCT),
    CONSTRAINT FK_NhanVienCongTy_CongTy FOREIGN KEY (MaCongTy) REFERENCES CongTy(MaCongTy),
    CONSTRAINT CK_NhanVienCongTy_GioiTinh CHECK (GioiTinh IN ('M', 'F', 'O')),
    CONSTRAINT CK_NhanVienCongTy_NgaySinh CHECK (NgaySinh < NgayVaoLam),
    -- TV6 sua: ngay nghi co the trung ngay vao lam theo quy uoc ngay bien bao gom.
    CONSTRAINT CK_NhanVienCongTy_NgayNghi CHECK (NgayNghiViec IS NULL OR NgayNghiViec >= NgayVaoLam)
) ENGINE=InnoDB;

CREATE TABLE DichVu (
    MaDichVu VARCHAR(20) NOT NULL,
    MaToaNha VARCHAR(20) NOT NULL,
    MaLoaiDV VARCHAR(20) NOT NULL,
    TenDichVu VARCHAR(120) NOT NULL,
    DonGiaCoBan DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_DichVu PRIMARY KEY (MaDichVu),
    CONSTRAINT FK_DichVu_ToaNha FOREIGN KEY (MaToaNha) REFERENCES ToaNha(MaToaNha),
    CONSTRAINT FK_DichVu_LoaiDichVu FOREIGN KEY (MaLoaiDV) REFERENCES LoaiDichVu(MaLoaiDV),
    -- TV6 sua: thong nhat dieu kien don gia co ban voi form va API.
    CONSTRAINT CK_DichVu_DonGia CHECK (DonGiaCoBan > 0)
) ENGINE=InnoDB;

CREATE TABLE NhanVienToaNha (
    MaNVTN VARCHAR(20) NOT NULL,
    MaToaNha VARCHAR(20) NOT NULL,
    MaQuanLy VARCHAR(20) NULL,
    LoaiNV VARCHAR(10) NOT NULL,
    HoTen VARCHAR(150) NOT NULL,
    GioiTinh CHAR(1) NOT NULL,
    NgaySinh DATE NOT NULL,
    DienThoai VARCHAR(20) NULL,
    Email VARCHAR(254) NULL,
    NgayVaoLam DATE NOT NULL,
    CONSTRAINT PK_NhanVienToaNha PRIMARY KEY (MaNVTN),
    CONSTRAINT FK_NhanVienToaNha_ToaNha FOREIGN KEY (MaToaNha) REFERENCES ToaNha(MaToaNha),
    CONSTRAINT FK_NhanVienToaNha_QuanLy FOREIGN KEY (MaQuanLy) REFERENCES NhanVienToaNha(MaNVTN),
    CONSTRAINT CK_NhanVienToaNha_Loai CHECK (LoaiNV IN ('QUAN_LY', 'DICH_VU')),
    CONSTRAINT CK_NhanVienToaNha_QuanLy CHECK (
        (LoaiNV = 'QUAN_LY' AND MaQuanLy IS NULL)
        OR (LoaiNV = 'DICH_VU' AND MaQuanLy IS NOT NULL AND MaQuanLy <> MaNVTN)),
    CONSTRAINT CK_NhanVienToaNha_GioiTinh CHECK (GioiTinh IN ('M', 'F', 'O')),
    CONSTRAINT CK_NhanVienToaNha_Ngay CHECK (NgaySinh < NgayVaoLam)
) ENGINE=InnoDB;

CREATE TABLE HoaDonThang (
    MaHoaDon INT NOT NULL AUTO_INCREMENT,
    MaCongTy VARCHAR(20) NOT NULL,
    MaToaNha VARCHAR(20) NOT NULL,
    Thang TINYINT NOT NULL,
    Nam SMALLINT NOT NULL,
    NgayLap DATE NOT NULL DEFAULT (CURRENT_DATE),
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'CHUA_THANH_TOAN',
    NgayThanhToan DATE NULL,
    NguoiThu VARCHAR(100) NULL,
    CONSTRAINT PK_HoaDonThang PRIMARY KEY (MaHoaDon),
    CONSTRAINT CK_HoaDonThang_ThanhToan CHECK (
        (TrangThai = 'CHUA_THANH_TOAN' AND NgayThanhToan IS NULL AND NguoiThu IS NULL)
        OR (TrangThai = 'DA_THANH_TOAN' AND NgayThanhToan IS NOT NULL AND NgayThanhToan >= NgayLap
            AND (NguoiThu IS NULL OR CHAR_LENGTH(TRIM(NguoiThu)) > 0))),
    CONSTRAINT FK_HoaDonThang_CongTy FOREIGN KEY (MaCongTy) REFERENCES CongTy(MaCongTy),
    CONSTRAINT FK_HoaDonThang_ToaNha FOREIGN KEY (MaToaNha) REFERENCES ToaNha(MaToaNha),
    CONSTRAINT UQ_HoaDonThang_Ky UNIQUE (MaCongTy, MaToaNha, Thang, Nam),
    CONSTRAINT CK_HoaDonThang_Thang CHECK (Thang BETWEEN 1 AND 12),
    CONSTRAINT CK_HoaDonThang_Nam CHECK (Nam BETWEEN 1900 AND 9999)
) ENGINE=InnoDB;

CREATE TABLE ChiPhiVanHanh (
    MaChiPhi BIGINT NOT NULL AUTO_INCREMENT,
    MaToaNha VARCHAR(20) NOT NULL,
    Thang TINYINT NOT NULL,
    Nam SMALLINT NOT NULL,
    LoaiChiPhi VARCHAR(100) NOT NULL,
    SoTien DECIMAL(18,2) NOT NULL,
    MoTa VARCHAR(300) NOT NULL DEFAULT '',
    CONSTRAINT PK_ChiPhiVanHanh PRIMARY KEY (MaChiPhi),
    CONSTRAINT FK_ChiPhiVanHanh_ToaNha FOREIGN KEY (MaToaNha) REFERENCES ToaNha(MaToaNha),
    CONSTRAINT CK_ChiPhiVanHanh_Thang CHECK (Thang BETWEEN 1 AND 12),
    CONSTRAINT CK_ChiPhiVanHanh_Nam CHECK (Nam BETWEEN 1900 AND 9999),
    CONSTRAINT CK_ChiPhiVanHanh_SoTien CHECK (SoTien > 0)
) ENGINE=InnoDB;

CREATE TABLE HopDongThue (
    MaHopDong VARCHAR(20) NOT NULL,
    MaCongTy VARCHAR(20) NOT NULL,
    MaVanPhong VARCHAR(20) NOT NULL,
    NgayBatDau DATE NOT NULL,
    NgayKetThuc DATE NULL,
    CONSTRAINT PK_HopDongThue PRIMARY KEY (MaHopDong),
    CONSTRAINT FK_HopDongThue_CongTy FOREIGN KEY (MaCongTy) REFERENCES CongTy(MaCongTy),
    CONSTRAINT FK_HopDongThue_VanPhong FOREIGN KEY (MaVanPhong) REFERENCES VanPhong(MaVanPhong),
    -- TV6 sua: cho phep hop dong co hieu luc dung mot ngay.
    CONSTRAINT CK_HopDongThue_Ngay CHECK (NgayKetThuc IS NULL OR NgayKetThuc >= NgayBatDau)
) ENGINE=InnoDB;

CREATE TABLE SuDungDichVu (
    MaCongTy VARCHAR(20) NOT NULL,
    MaDichVu VARCHAR(20) NOT NULL,
    NgayBatDau DATE NOT NULL,
    NgayKetThuc DATE NULL,
    CONSTRAINT PK_SuDungDichVu PRIMARY KEY (MaCongTy, MaDichVu, NgayBatDau),
    CONSTRAINT FK_SuDungDichVu_CongTy FOREIGN KEY (MaCongTy) REFERENCES CongTy(MaCongTy),
    CONSTRAINT FK_SuDungDichVu_DichVu FOREIGN KEY (MaDichVu) REFERENCES DichVu(MaDichVu),
    -- TV6 sua: dang ky dich vu mot ngay cung hop le.
    CONSTRAINT CK_SuDungDichVu_Ngay CHECK (NgayKetThuc IS NULL OR NgayKetThuc >= NgayBatDau)
) ENGINE=InnoDB;

CREATE TABLE ChiTietSuDungNV (
    MaSuDung BIGINT NOT NULL AUTO_INCREMENT,
    MaNVCT VARCHAR(20) NOT NULL,
    MaDichVu VARCHAR(20) NOT NULL,
    NgaySuDung DATE NOT NULL DEFAULT (CURRENT_DATE),
    SoLuot INT NOT NULL DEFAULT 1,
    DonGiaApDung DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_ChiTietSuDungNV PRIMARY KEY (MaSuDung),
    CONSTRAINT FK_ChiTietSuDungNV_NhanVien FOREIGN KEY (MaNVCT) REFERENCES NhanVienCongTy(MaNVCT),
    CONSTRAINT FK_ChiTietSuDungNV_DichVu FOREIGN KEY (MaDichVu) REFERENCES DichVu(MaDichVu),
    CONSTRAINT UQ_ChiTietSuDungNV_Ngay UNIQUE (MaNVCT, MaDichVu, NgaySuDung),
    CONSTRAINT CK_ChiTietSuDungNV_SoLuot CHECK (SoLuot > 0),
    CONSTRAINT CK_ChiTietSuDungNV_DonGia CHECK (DonGiaApDung >= 0)
) ENGINE=InnoDB;

CREATE TABLE PhanCongNVTN (
    MaNVTN VARCHAR(20) NOT NULL,
    Thang TINYINT NOT NULL,
    Nam SMALLINT NOT NULL,
    MaDichVu VARCHAR(20) NULL,
    MaBac VARCHAR(20) NOT NULL,
    CONSTRAINT PK_PhanCongNVTN PRIMARY KEY (MaNVTN, Thang, Nam),
    CONSTRAINT FK_PhanCongNVTN_NhanVien FOREIGN KEY (MaNVTN) REFERENCES NhanVienToaNha(MaNVTN),
    CONSTRAINT FK_PhanCongNVTN_DichVu FOREIGN KEY (MaDichVu) REFERENCES DichVu(MaDichVu),
    CONSTRAINT FK_PhanCongNVTN_Bac FOREIGN KEY (MaBac) REFERENCES BacCongViec(MaBac),
    CONSTRAINT CK_PhanCongNVTN_Thang CHECK (Thang BETWEEN 1 AND 12),
    CONSTRAINT CK_PhanCongNVTN_Nam CHECK (Nam BETWEEN 1900 AND 9999)
) ENGINE=InnoDB;

CREATE TABLE ChiTietHoaDon (
    MaChiTiet BIGINT NOT NULL AUTO_INCREMENT,
    MaHoaDon INT NOT NULL,
    LoaiKhoan VARCHAR(20) NOT NULL,
    MaVanPhong VARCHAR(20) NULL,
    MaDichVu VARCHAR(20) NULL,
    SoLuong DECIMAL(12,2) NOT NULL DEFAULT 1,
    DonGiaApDung DECIMAL(18,2) NOT NULL,
    TyLeNgay DECIMAL(12,10) NOT NULL DEFAULT 1,
    CONSTRAINT PK_ChiTietHoaDon PRIMARY KEY (MaChiTiet),
    CONSTRAINT FK_ChiTietHoaDon_HoaDon FOREIGN KEY (MaHoaDon) REFERENCES HoaDonThang(MaHoaDon),
    CONSTRAINT FK_ChiTietHoaDon_VanPhong FOREIGN KEY (MaVanPhong) REFERENCES VanPhong(MaVanPhong),
    CONSTRAINT FK_ChiTietHoaDon_DichVu FOREIGN KEY (MaDichVu) REFERENCES DichVu(MaDichVu),
    CONSTRAINT CK_ChiTietHoaDon_Loai CHECK (
        (LoaiKhoan = 'THUE_VAN_PHONG' AND MaVanPhong IS NOT NULL AND MaDichVu IS NULL)
        OR (LoaiKhoan IN ('DICH_VU_THANG', 'DICH_VU_LUOT') AND MaVanPhong IS NULL AND MaDichVu IS NOT NULL)),
    CONSTRAINT CK_ChiTietHoaDon_SoLuong CHECK (SoLuong > 0),
    CONSTRAINT CK_ChiTietHoaDon_DonGia CHECK (DonGiaApDung >= 0),
    CONSTRAINT CK_ChiTietHoaDon_TyLe CHECK (TyLeNgay > 0 AND TyLeNgay <= 1)
) ENGINE=InnoDB;

CREATE TABLE LuongThang (
    MaNVTN VARCHAR(20) NOT NULL,
    Thang TINYINT NOT NULL,
    Nam SMALLINT NOT NULL,
    LuongCoBan DECIMAL(18,2) NOT NULL,
    TienThuong DECIMAL(18,2) NOT NULL DEFAULT 0,
    CONSTRAINT PK_LuongThang PRIMARY KEY (MaNVTN, Thang, Nam),
    CONSTRAINT FK_LuongThang_PhanCong FOREIGN KEY (MaNVTN, Thang, Nam)
        REFERENCES PhanCongNVTN(MaNVTN, Thang, Nam),
    CONSTRAINT CK_LuongThang_Thang CHECK (Thang BETWEEN 1 AND 12),
    CONSTRAINT CK_LuongThang_Nam CHECK (Nam BETWEEN 1900 AND 9999),
    CONSTRAINT CK_LuongThang_Tien CHECK (LuongCoBan > 0 AND TienThuong >= 0)
) ENGINE=InnoDB;

CREATE INDEX IX_VanPhong_ToaNha ON VanPhong(MaToaNha);
CREATE INDEX IX_VanPhong_ViTri ON VanPhong(MaViTri);
CREATE INDEX IX_HopDongThue_VanPhong_Ngay ON HopDongThue(MaVanPhong, NgayBatDau, NgayKetThuc);
CREATE INDEX IX_HopDongThue_CongTy ON HopDongThue(MaCongTy);
CREATE INDEX IX_NhanVienCongTy_CongTy ON NhanVienCongTy(MaCongTy);
CREATE INDEX IX_DichVu_Loai ON DichVu(MaLoaiDV);
CREATE INDEX IX_SuDungDichVu_DichVu ON SuDungDichVu(MaDichVu, NgayBatDau, NgayKetThuc);
CREATE INDEX IX_ChiTietSuDungNV_DichVu_Ngay ON ChiTietSuDungNV(MaDichVu, NgaySuDung);
CREATE INDEX IX_NhanVienToaNha_ToaNha ON NhanVienToaNha(MaToaNha);
CREATE INDEX IX_NhanVienToaNha_QuanLy ON NhanVienToaNha(MaQuanLy);
CREATE INDEX IX_PhanCongNVTN_DichVu ON PhanCongNVTN(MaDichVu);
CREATE INDEX IX_PhanCongNVTN_Bac ON PhanCongNVTN(MaBac);
CREATE INDEX IX_HoaDonThang_ToaNha_Ky ON HoaDonThang(MaToaNha, Nam, Thang);
CREATE INDEX IX_ChiTietHoaDon_HoaDon ON ChiTietHoaDon(MaHoaDon);
CREATE INDEX IX_ChiTietHoaDon_VanPhong ON ChiTietHoaDon(MaVanPhong);
CREATE INDEX IX_ChiTietHoaDon_DichVu ON ChiTietHoaDon(MaDichVu);
CREATE INDEX IX_ChiPhiVanHanh_ToaNha_Ky ON ChiPhiVanHanh(MaToaNha, Nam, Thang);

CREATE VIEW V_ChiTietHoaDon AS
SELECT MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay,
    ROUND(SoLuong * DonGiaApDung * TyLeNgay, 2) AS SoTien
FROM ChiTietHoaDon;

SELECT 'Schema created' AS KetQua,
    (SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE') AS SoBang,
    (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA = DATABASE()) AS SoFK;
