/* ============================================================================
   TV7 - MANH DOC RIENG CHI TAI SITE 1 (TRUNG TAM, TN01)
   Chua ho so thue/lien he cong ty va toan bo tien luong cua chuoi (mảnh dọc).
   Thay __SITE_DB__ = QLToaNha_Site1. Chi chay cho site trung tam.
   ============================================================================ */
CREATE TABLE __SITE_DB__.CongTy_HoSo (
    MaCongTy VARCHAR(20) NOT NULL PRIMARY KEY,
    MaSoThue VARCHAR(14) NOT NULL,
    DiaChi VARCHAR(300) NOT NULL,
    DienThoai VARCHAR(20) NULL,
    Email VARCHAR(254) NULL,
    CONSTRAINT UQ_CongTy_HoSo_MST UNIQUE (MaSoThue)
);
CREATE TABLE __SITE_DB__.BacCongViec_TaiChinh (
    MaBac VARCHAR(20) NOT NULL PRIMARY KEY,
    LuongCoBan DECIMAL(18,2) NOT NULL,
    HeSoDoanhThu DECIMAL(9,6) NOT NULL
);
CREATE TABLE __SITE_DB__.LuongThang_Tien (
    MaNVTN VARCHAR(20) NOT NULL,
    Thang TINYINT NOT NULL,
    Nam SMALLINT NOT NULL,
    LuongCoBan DECIMAL(18,2) NOT NULL,
    TienThuong DECIMAL(18,2) NOT NULL,
    PRIMARY KEY (MaNVTN, Thang, Nam)
);

INSERT INTO __SITE_DB__.CongTy_HoSo (MaCongTy, MaSoThue, DiaChi, DienThoai, Email)
SELECT MaCongTy, MaSoThue, DiaChi, DienThoai, Email FROM QLToaNha_BCNF.CongTy;
INSERT INTO __SITE_DB__.BacCongViec_TaiChinh (MaBac, LuongCoBan, HeSoDoanhThu)
SELECT MaBac, LuongCoBan, HeSoDoanhThu FROM QLToaNha_BCNF.BacCongViec;
INSERT INTO __SITE_DB__.LuongThang_Tien (MaNVTN, Thang, Nam, LuongCoBan, TienThuong)
SELECT MaNVTN, Thang, Nam, LuongCoBan, TienThuong FROM QLToaNha_BCNF.LuongThang;
