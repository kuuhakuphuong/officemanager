/* ============================================================================
   TV7 - MANH PHAN TAN CHO MOI SITE (MySQL 8.0)
   Template: thay __SITE_DB__ (QLToaNha_Site1/2/3) va __TOA_NHA__ (TN01/TN02/TN03)
   truoc khi chay. docker/init-db.sh lam viec thay the nay bang sed.
   Mo hinh: moi site giu MANH NGANG CHINH cua mot toa nha (toa nha __TOA_NHA__), cac
   MANH DAN XUAT (hop dong, log, hoa don, chi tiet, lich su luong) va BAN SAO TRA CUU
   (ThamSo, ViTri, LoaiDichVu, BacCongViec_TraCuu, CongTy_TraCuu, NhanVienCongTy).
   Du lieu lay tu CSDL trung tam QLToaNha_BCNF da nap seed TV3 (khong phai seed rieng).
   ============================================================================ */
DROP DATABASE IF EXISTS __SITE_DB__;
CREATE DATABASE __SITE_DB__ CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_as_ci;

-- ---------------------------------------------------------------- Ban sao tra cuu
CREATE TABLE __SITE_DB__.ThamSo (
    TenThamSo VARCHAR(50) NOT NULL PRIMARY KEY,
    GiaTri DECIMAL(18,6) NOT NULL,
    MoTa VARCHAR(300) NOT NULL
);
CREATE TABLE __SITE_DB__.ViTri (
    MaViTri VARCHAR(20) NOT NULL PRIMARY KEY,
    TenViTri VARCHAR(100) NOT NULL,
    DonGiaThueM2 DECIMAL(18,2) NOT NULL
);
CREATE TABLE __SITE_DB__.LoaiDichVu (
    MaLoaiDV VARCHAR(20) NOT NULL PRIMARY KEY,
    TenLoai VARCHAR(100) NOT NULL,
    KieuTinhPhi VARCHAR(10) NOT NULL,
    CoTinhTheoNguoi TINYINT(1) NOT NULL,
    CoTinhTheoDienTich TINYINT(1) NOT NULL
);
CREATE TABLE __SITE_DB__.BacCongViec_TraCuu (
    MaBac VARCHAR(20) NOT NULL PRIMARY KEY,
    TenBac VARCHAR(100) NOT NULL
);
CREATE TABLE __SITE_DB__.CongTy_TraCuu (
    MaCongTy VARCHAR(20) NOT NULL PRIMARY KEY,
    TenCongTy VARCHAR(200) NOT NULL,
    LinhVuc VARCHAR(100) NOT NULL
);
CREATE TABLE __SITE_DB__.NhanVienCongTy (
    MaNVCT VARCHAR(20) NOT NULL PRIMARY KEY,
    MaCongTy VARCHAR(20) NOT NULL,
    HoTen VARCHAR(150) NOT NULL,
    GioiTinh CHAR(1) NOT NULL,
    NgaySinh DATE NOT NULL,
    DienThoai VARCHAR(20) NULL,
    Email VARCHAR(254) NULL,
    ChucVu VARCHAR(100) NOT NULL,
    NgayVaoLam DATE NOT NULL,
    NgayNghiViec DATE NULL
);

-- ---------------------------------------------------------------- Manh ngang chinh (mot toa nha)
CREATE TABLE __SITE_DB__.ToaNha (
    MaToaNha VARCHAR(20) NOT NULL PRIMARY KEY,
    TenToaNha VARCHAR(150) NOT NULL,
    DiaChi VARCHAR(300) NOT NULL,
    SoTang SMALLINT NOT NULL,
    CONSTRAINT CK_ToaNha_Site CHECK (MaToaNha = '__TOA_NHA__')
);
CREATE TABLE __SITE_DB__.VanPhong (
    MaVanPhong VARCHAR(20) NOT NULL PRIMARY KEY,
    MaToaNha VARCHAR(20) NOT NULL,
    MaViTri VARCHAR(20) NOT NULL,
    Tang SMALLINT NOT NULL,
    DienTich DECIMAL(10,2) NOT NULL
);
CREATE TABLE __SITE_DB__.DichVu (
    MaDichVu VARCHAR(20) NOT NULL PRIMARY KEY,
    MaToaNha VARCHAR(20) NOT NULL,
    MaLoaiDV VARCHAR(20) NOT NULL,
    TenDichVu VARCHAR(120) NOT NULL,
    DonGiaCoBan DECIMAL(18,2) NOT NULL
);
CREATE TABLE __SITE_DB__.NhanVienToaNha (
    MaNVTN VARCHAR(20) NOT NULL PRIMARY KEY,
    MaToaNha VARCHAR(20) NOT NULL,
    MaQuanLy VARCHAR(20) NULL,
    LoaiNV VARCHAR(10) NOT NULL,
    HoTen VARCHAR(150) NOT NULL,
    GioiTinh CHAR(1) NOT NULL,
    NgaySinh DATE NOT NULL,
    DienThoai VARCHAR(20) NULL,
    Email VARCHAR(254) NULL,
    NgayVaoLam DATE NOT NULL
);
CREATE TABLE __SITE_DB__.HoaDonThang (
    MaHoaDon INT NOT NULL PRIMARY KEY,
    MaCongTy VARCHAR(20) NOT NULL,
    MaToaNha VARCHAR(20) NOT NULL,
    Thang TINYINT NOT NULL,
    Nam SMALLINT NOT NULL,
    NgayLap DATE NOT NULL,
    TrangThai VARCHAR(20) NOT NULL,
    NgayThanhToan DATE NULL,
    NguoiThu VARCHAR(100) NULL,
    CONSTRAINT UQ_HoaDonThang_Ky_Site UNIQUE (MaCongTy, MaToaNha, Thang, Nam)
);
CREATE TABLE __SITE_DB__.ChiPhiVanHanh (
    MaChiPhi BIGINT NOT NULL PRIMARY KEY,
    MaToaNha VARCHAR(20) NOT NULL,
    Thang TINYINT NOT NULL,
    Nam SMALLINT NOT NULL,
    LoaiChiPhi VARCHAR(100) NOT NULL,
    SoTien DECIMAL(18,2) NOT NULL,
    MoTa VARCHAR(300) NOT NULL
);

-- ---------------------------------------------------------------- Manh ngang dan xuat (semi-join)
CREATE TABLE __SITE_DB__.HopDongThue (
    MaHopDong VARCHAR(20) NOT NULL PRIMARY KEY,
    MaCongTy VARCHAR(20) NOT NULL,
    MaVanPhong VARCHAR(20) NOT NULL,
    NgayBatDau DATE NOT NULL,
    NgayKetThuc DATE NULL
);
CREATE TABLE __SITE_DB__.SuDungDichVu (
    MaCongTy VARCHAR(20) NOT NULL,
    MaDichVu VARCHAR(20) NOT NULL,
    NgayBatDau DATE NOT NULL,
    NgayKetThuc DATE NULL,
    PRIMARY KEY (MaCongTy, MaDichVu, NgayBatDau)
);
CREATE TABLE __SITE_DB__.ChiTietSuDungNV (
    MaSuDung BIGINT NOT NULL PRIMARY KEY,
    MaNVCT VARCHAR(20) NOT NULL,
    MaDichVu VARCHAR(20) NOT NULL,
    NgaySuDung DATE NOT NULL,
    SoLuot INT NOT NULL,
    DonGiaApDung DECIMAL(18,2) NOT NULL
);
CREATE TABLE __SITE_DB__.PhanCongNVTN (
    MaNVTN VARCHAR(20) NOT NULL,
    Thang TINYINT NOT NULL,
    Nam SMALLINT NOT NULL,
    MaDichVu VARCHAR(20) NULL,
    MaBac VARCHAR(20) NOT NULL,
    PRIMARY KEY (MaNVTN, Thang, Nam)
);
CREATE TABLE __SITE_DB__.ChiTietHoaDon (
    MaChiTiet BIGINT NOT NULL PRIMARY KEY,
    MaHoaDon INT NOT NULL,
    LoaiKhoan VARCHAR(20) NOT NULL,
    MaVanPhong VARCHAR(20) NULL,
    MaDichVu VARCHAR(20) NULL,
    SoLuong DECIMAL(12,2) NOT NULL,
    DonGiaApDung DECIMAL(18,2) NOT NULL,
    TyLeNgay DECIMAL(12,10) NOT NULL
);
CREATE TABLE __SITE_DB__.LuongThang_Ky (
    MaNVTN VARCHAR(20) NOT NULL,
    Thang TINYINT NOT NULL,
    Nam SMALLINT NOT NULL,
    PRIMARY KEY (MaNVTN, Thang, Nam)
);

-- ---------------------------------------------------------------- Nap manh tu CSDL trung tam
INSERT INTO __SITE_DB__.ThamSo (TenThamSo, GiaTri, MoTa)
SELECT TenThamSo, GiaTri, MoTa FROM QLToaNha_BCNF.ThamSo;
INSERT INTO __SITE_DB__.ViTri (MaViTri, TenViTri, DonGiaThueM2)
SELECT MaViTri, TenViTri, DonGiaThueM2 FROM QLToaNha_BCNF.ViTri;
INSERT INTO __SITE_DB__.LoaiDichVu (MaLoaiDV, TenLoai, KieuTinhPhi, CoTinhTheoNguoi, CoTinhTheoDienTich)
SELECT MaLoaiDV, TenLoai, KieuTinhPhi, CoTinhTheoNguoi, CoTinhTheoDienTich FROM QLToaNha_BCNF.LoaiDichVu;
INSERT INTO __SITE_DB__.BacCongViec_TraCuu (MaBac, TenBac)
SELECT MaBac, TenBac FROM QLToaNha_BCNF.BacCongViec;
INSERT INTO __SITE_DB__.CongTy_TraCuu (MaCongTy, TenCongTy, LinhVuc)
SELECT MaCongTy, TenCongTy, LinhVuc FROM QLToaNha_BCNF.CongTy;
INSERT INTO __SITE_DB__.NhanVienCongTy (MaNVCT, MaCongTy, HoTen, GioiTinh, NgaySinh, DienThoai, Email, ChucVu, NgayVaoLam, NgayNghiViec)
SELECT MaNVCT, MaCongTy, HoTen, GioiTinh, NgaySinh, DienThoai, Email, ChucVu, NgayVaoLam, NgayNghiViec
FROM QLToaNha_BCNF.NhanVienCongTy;

INSERT INTO __SITE_DB__.ToaNha (MaToaNha, TenToaNha, DiaChi, SoTang)
SELECT MaToaNha, TenToaNha, DiaChi, SoTang FROM QLToaNha_BCNF.ToaNha WHERE MaToaNha = '__TOA_NHA__';
INSERT INTO __SITE_DB__.VanPhong (MaVanPhong, MaToaNha, MaViTri, Tang, DienTich)
SELECT MaVanPhong, MaToaNha, MaViTri, Tang, DienTich FROM QLToaNha_BCNF.VanPhong WHERE MaToaNha = '__TOA_NHA__';
INSERT INTO __SITE_DB__.DichVu (MaDichVu, MaToaNha, MaLoaiDV, TenDichVu, DonGiaCoBan)
SELECT MaDichVu, MaToaNha, MaLoaiDV, TenDichVu, DonGiaCoBan FROM QLToaNha_BCNF.DichVu WHERE MaToaNha = '__TOA_NHA__';
INSERT INTO __SITE_DB__.NhanVienToaNha (MaNVTN, MaToaNha, MaQuanLy, LoaiNV, HoTen, GioiTinh, NgaySinh, DienThoai, Email, NgayVaoLam)
SELECT MaNVTN, MaToaNha, MaQuanLy, LoaiNV, HoTen, GioiTinh, NgaySinh, DienThoai, Email, NgayVaoLam
FROM QLToaNha_BCNF.NhanVienToaNha WHERE MaToaNha = '__TOA_NHA__';
INSERT INTO __SITE_DB__.ChiPhiVanHanh (MaChiPhi, MaToaNha, Thang, Nam, LoaiChiPhi, SoTien, MoTa)
SELECT MaChiPhi, MaToaNha, Thang, Nam, LoaiChiPhi, SoTien, MoTa FROM QLToaNha_BCNF.ChiPhiVanHanh WHERE MaToaNha = '__TOA_NHA__';
INSERT INTO __SITE_DB__.HoaDonThang (MaHoaDon, MaCongTy, MaToaNha, Thang, Nam, NgayLap, TrangThai, NgayThanhToan, NguoiThu)
SELECT MaHoaDon, MaCongTy, MaToaNha, Thang, Nam, NgayLap, TrangThai, NgayThanhToan, NguoiThu
FROM QLToaNha_BCNF.HoaDonThang WHERE MaToaNha = '__TOA_NHA__';

INSERT INTO __SITE_DB__.HopDongThue (MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc)
SELECT MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc FROM QLToaNha_BCNF.HopDongThue
WHERE MaVanPhong IN (SELECT MaVanPhong FROM __SITE_DB__.VanPhong);
INSERT INTO __SITE_DB__.SuDungDichVu (MaCongTy, MaDichVu, NgayBatDau, NgayKetThuc)
SELECT MaCongTy, MaDichVu, NgayBatDau, NgayKetThuc FROM QLToaNha_BCNF.SuDungDichVu
WHERE MaDichVu IN (SELECT MaDichVu FROM __SITE_DB__.DichVu);
INSERT INTO __SITE_DB__.ChiTietSuDungNV (MaSuDung, MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung)
SELECT MaSuDung, MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung FROM QLToaNha_BCNF.ChiTietSuDungNV
WHERE MaDichVu IN (SELECT MaDichVu FROM __SITE_DB__.DichVu);
INSERT INTO __SITE_DB__.PhanCongNVTN (MaNVTN, Thang, Nam, MaDichVu, MaBac)
SELECT MaNVTN, Thang, Nam, MaDichVu, MaBac FROM QLToaNha_BCNF.PhanCongNVTN
WHERE MaNVTN IN (SELECT MaNVTN FROM __SITE_DB__.NhanVienToaNha);
INSERT INTO __SITE_DB__.ChiTietHoaDon (MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
SELECT MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay FROM QLToaNha_BCNF.ChiTietHoaDon
WHERE MaHoaDon IN (SELECT MaHoaDon FROM __SITE_DB__.HoaDonThang);
INSERT INTO __SITE_DB__.LuongThang_Ky (MaNVTN, Thang, Nam)
SELECT MaNVTN, Thang, Nam FROM QLToaNha_BCNF.LuongThang
WHERE MaNVTN IN (SELECT MaNVTN FROM __SITE_DB__.NhanVienToaNha);

SELECT '__SITE_DB__' AS TenDatabase, '__TOA_NHA__' AS MaToaNha,
    (SELECT COUNT(*) FROM __SITE_DB__.VanPhong) AS SoVanPhong,
    (SELECT COUNT(*) FROM __SITE_DB__.HopDongThue) AS SoHopDong,
    (SELECT COUNT(*) FROM __SITE_DB__.HoaDonThang) AS SoHoaDon,
    (SELECT COUNT(*) FROM __SITE_DB__.ChiTietSuDungNV) AS SoNhatKyDichVu,
    (SELECT COUNT(*) FROM __SITE_DB__.LuongThang_Ky) AS SoKyLuongSite;
