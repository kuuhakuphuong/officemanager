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

IF (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0) <> 18
    THROW 51001, N'Can chay 01_CreateSchema.sql thanh cong truoc.', 1;

IF EXISTS (
    SELECT 1 FROM sys.partitions AS part
    JOIN sys.tables AS tbl ON tbl.object_id = part.object_id
    WHERE tbl.is_ms_shipped = 0 AND part.index_id IN (0, 1) AND part.rows > 0
)
    THROW 51002, N'Database da co du lieu. Seed chi chay tren 18 bang rong; khong xoa du lieu cu.', 1;

DECLARE @TuNgay date = '20260801', @DenNgay date = '20261001';

BEGIN TRY
    BEGIN TRANSACTION;

    CREATE TABLE #So (So int NOT NULL PRIMARY KEY);
    INSERT #So(So)
    SELECT chuc.So * 10 + donvi.So
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS chuc(So)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS donvi(So);

    CREATE TABLE #Ngay (Ngay date NOT NULL PRIMARY KEY);
    INSERT #Ngay(Ngay)
    SELECT DATEADD(day, So, @TuNgay) FROM #So WHERE So < DATEDIFF(day, @TuNgay, @DenNgay);

    CREATE TABLE #Ky (Thang tinyint NOT NULL, Nam smallint NOT NULL, NgayDau date NOT NULL PRIMARY KEY);
    INSERT #Ky(Thang, Nam, NgayDau)
    VALUES (8, 2026, '20260801'), (9, 2026, '20260901');

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

    INSERT dbo.BacCongViec(MaBac, TenBac, LuongCoBan, HeSoDoanhThu) VALUES
        ('BAC_QL', N'Quan ly toa nha', 18000000, 0),
        ('BAC_AN', N'Nhan vien nha an', 8000000, 0.05),
        ('BAC_XE', N'Nhan vien bai xe', 7500000, 0.04);

    INSERT dbo.ToaNha(MaToaNha, TenToaNha, DiaChi, SoTang)
    SELECT CONCAT('TN0', So), CONCAT(N'Toa nha mau ', So),
        CONCAT(So * 10, N' Duong Mo Phong, Ha Noi'), 8 + So
    FROM #So WHERE So BETWEEN 1 AND 3;

    INSERT dbo.CongTy(MaCongTy, TenCongTy, MaSoThue, DiaChi, DienThoai, Email, LinhVuc)
    SELECT CONCAT('CT0', So), CONCAT(N'Cong ty du lieu mau ', So),
        CONCAT('010900000', So), CONCAT(So, N' Duong Du Lieu Mau, Ha Noi'),
        CONCAT('090000000', So), CONCAT('company', So, '@example.com'),
        CASE WHEN So % 2 = 0 THEN N'Thuong mai' ELSE N'Cong nghe thong tin' END
    FROM #So WHERE So BETWEEN 1 AND 6;

    INSERT dbo.VanPhong(MaVanPhong, MaToaNha, MaViTri, Tang, DienTich)
    SELECT CONCAT('VP', RIGHT(CONCAT('00', So), 2)), CONCAT('TN0', (So - 1) / 4 + 1),
        CASE WHEN So % 2 = 0 THEN 'VT_MAT_TIEN' ELSE 'VT_TRONG' END,
        (So - 1) % 4 + 1, CASE WHEN So % 2 = 0 THEN 120 ELSE 80 END
    FROM #So WHERE So BETWEEN 1 AND 12;

    INSERT dbo.HopDongThue(MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc)
    SELECT CONCAT('HD', RIGHT(CONCAT('00', So), 2)), CONCAT('CT0', (So - 1) / 2 + 1),
        CONCAT('VP', RIGHT(CONCAT('00', So), 2)), '20260701', '20270630'
    FROM #So WHERE So BETWEEN 1 AND 12;

    INSERT dbo.NhanVienCongTy(MaNVCT, MaCongTy, HoTen, GioiTinh, NgaySinh,
        DienThoai, Email, ChucVu, NgayVaoLam, NgayNghiViec)
    SELECT CONCAT('NVCT', RIGHT(CONCAT('000', So), 3)), CONCAT('CT0', (So - 1) / 10 + 1),
        CONCAT(N'Nhan vien mau ', RIGHT(CONCAT('000', So), 3)),
        CASE WHEN So % 2 = 0 THEN 'F' ELSE 'M' END,
        DATEADD(day, So * 17, CONVERT(date, '19900101')),
        CONCAT('09100000', RIGHT(CONCAT('00', So), 2)), CONCAT('employee', So, '@example.com'),
        N'Chuyen vien', '20260701', NULL
    FROM #So WHERE So BETWEEN 1 AND 60;

    INSERT dbo.DichVu(MaDichVu, MaToaNha, MaLoaiDV, TenDichVu, DonGiaCoBan)
    SELECT CONCAT(loai.TienTo, RIGHT(toanha.MaToaNha, 2)), toanha.MaToaNha,
        loai.MaLoaiDV, CONCAT(loai.Ten, N' - ', toanha.TenToaNha), loai.DonGia
    FROM dbo.ToaNha AS toanha
    CROSS JOIN (VALUES
        ('AN', 'AN_UONG', N'An trua', CONVERT(decimal(18,2), 35000)),
        ('XE', 'GUI_XE', N'Gui xe may', CONVERT(decimal(18,2), 5000)),
        ('VS', 'VE_SINH', N'Ve sinh', CONVERT(decimal(18,2), 1500000))
    ) AS loai(TienTo, MaLoaiDV, Ten, DonGia);

    INSERT dbo.SuDungDichVu(MaCongTy, MaDichVu, NgayBatDau, NgayKetThuc)
    SELECT DISTINCT hd.MaCongTy, dv.MaDichVu, '20260701', '20270630'
    FROM dbo.HopDongThue AS hd
    JOIN dbo.VanPhong AS vp ON vp.MaVanPhong = hd.MaVanPhong
    JOIN dbo.DichVu AS dv ON dv.MaToaNha = vp.MaToaNha;

    INSERT dbo.ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung)
    SELECT nv.MaNVCT, dv.MaDichVu, ngay.Ngay, 1, dv.DonGiaCoBan
    FROM dbo.NhanVienCongTy AS nv
    JOIN dbo.SuDungDichVu AS dk ON dk.MaCongTy = nv.MaCongTy
    JOIN dbo.DichVu AS dv ON dv.MaDichVu = dk.MaDichVu
    JOIN dbo.LoaiDichVu AS loai ON loai.MaLoaiDV = dv.MaLoaiDV AND loai.KieuTinhPhi = 'LUOT'
    CROSS JOIN #Ngay AS ngay;

    INSERT dbo.NhanVienToaNha(MaNVTN, MaToaNha, MaQuanLy, LoaiNV, HoTen,
        GioiTinh, NgaySinh, DienThoai, Email, NgayVaoLam)
    SELECT CONCAT('QL', RIGHT(MaToaNha, 2)), MaToaNha, NULL, 'QUAN_LY',
        CONCAT(N'Quan ly mau ', MaToaNha), 'M', '19850101', NULL,
        CONCAT('manager', RIGHT(MaToaNha, 2), '@example.com'), '20260101'
    FROM dbo.ToaNha;

    INSERT dbo.NhanVienToaNha(MaNVTN, MaToaNha, MaQuanLy, LoaiNV, HoTen,
        GioiTinh, NgaySinh, DienThoai, Email, NgayVaoLam)
    SELECT CONCAT('NV', dv.MaDichVu), dv.MaToaNha, CONCAT('QL', RIGHT(dv.MaToaNha, 2)),
        'DICH_VU', CONCAT(N'Nhan vien mau ', dv.MaDichVu),
        CASE WHEN dv.MaLoaiDV = 'AN_UONG' THEN 'F' ELSE 'M' END,
        '19920101', NULL, CONCAT('staff', dv.MaDichVu, '@example.com'), '20260101'
    FROM dbo.DichVu AS dv WHERE dv.MaLoaiDV IN ('AN_UONG', 'GUI_XE');

    INSERT dbo.PhanCongNVTN(MaNVTN, Thang, Nam, MaDichVu, MaBac)
    SELECT nv.MaNVTN, ky.Thang, ky.Nam, dv.MaDichVu,
        CASE WHEN nv.LoaiNV = 'QUAN_LY' THEN 'BAC_QL'
            WHEN dv.MaLoaiDV = 'AN_UONG' THEN 'BAC_AN' ELSE 'BAC_XE' END
    FROM dbo.NhanVienToaNha AS nv
    LEFT JOIN dbo.DichVu AS dv ON nv.MaNVTN = CONCAT('NV', dv.MaDichVu)
    CROSS JOIN #Ky AS ky;

    INSERT dbo.LuongThang(MaNVTN, Thang, Nam, LuongCoBan, TienThuong)
    SELECT pc.MaNVTN, pc.Thang, pc.Nam, bac.LuongCoBan,
        CONVERT(decimal(18,2), COALESCE(dt.DoanhThu, 0) * bac.HeSoDoanhThu)
    FROM dbo.PhanCongNVTN AS pc
    JOIN dbo.BacCongViec AS bac ON bac.MaBac = pc.MaBac
    OUTER APPLY (
        SELECT SUM(CONVERT(decimal(18,2), logdv.SoLuot) * logdv.DonGiaApDung) AS DoanhThu
        FROM dbo.ChiTietSuDungNV AS logdv
        WHERE logdv.MaDichVu = pc.MaDichVu
            AND logdv.NgaySuDung >= DATEFROMPARTS(pc.Nam, pc.Thang, 1)
            AND logdv.NgaySuDung < DATEADD(month, 1, DATEFROMPARTS(pc.Nam, pc.Thang, 1))
    ) AS dt;

    INSERT dbo.HoaDonThang(MaCongTy, MaToaNha, Thang, Nam, NgayLap)
    SELECT DISTINCT hd.MaCongTy, vp.MaToaNha, ky.Thang, ky.Nam, EOMONTH(ky.NgayDau)
    FROM dbo.HopDongThue AS hd
    JOIN dbo.VanPhong AS vp ON vp.MaVanPhong = hd.MaVanPhong
    CROSS JOIN #Ky AS ky;

    UPDATE dbo.HoaDonThang
    SET TrangThai = 'DA_THANH_TOAN', NgayThanhToan = DATEADD(day, 5, NgayLap),
        NguoiThu = N'Thu ngan mau'
    WHERE Thang = 8;

    INSERT dbo.ChiTietHoaDon(MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
    SELECT hoadon.MaHoaDon, 'THUE_VAN_PHONG', vp.MaVanPhong, NULL,
        vp.DienTich, vitri.DonGiaThueM2, 1
    FROM dbo.HoaDonThang AS hoadon
    JOIN dbo.HopDongThue AS hd ON hd.MaCongTy = hoadon.MaCongTy
    JOIN dbo.VanPhong AS vp ON vp.MaVanPhong = hd.MaVanPhong AND vp.MaToaNha = hoadon.MaToaNha
    JOIN dbo.ViTri AS vitri ON vitri.MaViTri = vp.MaViTri;

    ;WITH CauHinh AS (
        SELECT
            MAX(CASE WHEN TenThamSo = 'NGUONG_NGUOI' THEN GiaTri END) AS NguongNguoi,
            MAX(CASE WHEN TenThamSo = 'BUOC_NGUOI' THEN GiaTri END) AS BuocNguoi,
            MAX(CASE WHEN TenThamSo = 'NGUONG_DIEN_TICH' THEN GiaTri END) AS NguongDienTich,
            MAX(CASE WHEN TenThamSo = 'BUOC_DIEN_TICH' THEN GiaTri END) AS BuocDienTich,
            MAX(CASE WHEN TenThamSo = 'TY_LE_TANG_GIA' THEN GiaTri END) AS TyLe
        FROM dbo.ThamSo
    ), MatBang AS (
        SELECT hd.MaCongTy, vp.MaToaNha, SUM(vp.DienTich) AS DienTich
        FROM dbo.HopDongThue AS hd
        JOIN dbo.VanPhong AS vp ON vp.MaVanPhong = hd.MaVanPhong
        GROUP BY hd.MaCongTy, vp.MaToaNha
    ), NhanSu AS (
        SELECT MaCongTy, COUNT(*) AS SoNguoi FROM dbo.NhanVienCongTy GROUP BY MaCongTy
    )
    INSERT dbo.ChiTietHoaDon(MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
    SELECT hoadon.MaHoaDon, 'DICH_VU_THANG', NULL, dv.MaDichVu, 1,
        dv.DonGiaCoBan * (1 + cauhinh.TyLe * (
            CASE WHEN loai.CoTinhTheoNguoi = 1 AND nhansu.SoNguoi > cauhinh.NguongNguoi
                THEN CEILING((nhansu.SoNguoi - cauhinh.NguongNguoi) / cauhinh.BuocNguoi) ELSE 0 END
            + CASE WHEN loai.CoTinhTheoDienTich = 1 AND matbang.DienTich > cauhinh.NguongDienTich
                THEN CEILING((matbang.DienTich - cauhinh.NguongDienTich) / cauhinh.BuocDienTich) ELSE 0 END)), 1
    FROM dbo.HoaDonThang AS hoadon
    JOIN dbo.SuDungDichVu AS dk ON dk.MaCongTy = hoadon.MaCongTy
    JOIN dbo.DichVu AS dv ON dv.MaDichVu = dk.MaDichVu AND dv.MaToaNha = hoadon.MaToaNha
    JOIN dbo.LoaiDichVu AS loai ON loai.MaLoaiDV = dv.MaLoaiDV AND loai.KieuTinhPhi = 'THANG'
    JOIN MatBang AS matbang ON matbang.MaCongTy = hoadon.MaCongTy AND matbang.MaToaNha = hoadon.MaToaNha
    JOIN NhanSu AS nhansu ON nhansu.MaCongTy = hoadon.MaCongTy
    CROSS JOIN CauHinh AS cauhinh;

    INSERT dbo.ChiTietHoaDon(MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
    SELECT hoadon.MaHoaDon, 'DICH_VU_LUOT', NULL, logdv.MaDichVu,
        SUM(logdv.SoLuot), logdv.DonGiaApDung, 1
    FROM dbo.HoaDonThang AS hoadon
    JOIN dbo.NhanVienCongTy AS nv ON nv.MaCongTy = hoadon.MaCongTy
    JOIN dbo.ChiTietSuDungNV AS logdv ON logdv.MaNVCT = nv.MaNVCT
        AND logdv.NgaySuDung >= DATEFROMPARTS(hoadon.Nam, hoadon.Thang, 1)
        AND logdv.NgaySuDung < DATEADD(month, 1, DATEFROMPARTS(hoadon.Nam, hoadon.Thang, 1))
    JOIN dbo.DichVu AS dv ON dv.MaDichVu = logdv.MaDichVu AND dv.MaToaNha = hoadon.MaToaNha
    GROUP BY hoadon.MaHoaDon, logdv.MaDichVu, logdv.DonGiaApDung;

    INSERT dbo.ChiPhiVanHanh(MaToaNha, Thang, Nam, LoaiChiPhi, SoTien, MoTa)
    SELECT tn.MaToaNha, ky.Thang, ky.Nam, chiphi.Loai, chiphi.Tien,
        CONCAT(N'Chi phi mau thang ', ky.Thang, '/', ky.Nam)
    FROM dbo.ToaNha AS tn CROSS JOIN #Ky AS ky
    CROSS JOIN (VALUES (N'Dien nuoc', 12000000), (N'Bao tri', 5000000), (N'Vat tu', 3000000)) AS chiphi(Loai, Tien);

    IF (SELECT COUNT_BIG(*) FROM dbo.ChiTietSuDungNV) <> 7320
        THROW 51003, N'So log khong dung 7.320. Huy toan bo seed.', 1;
    IF (SELECT COUNT(*) FROM dbo.HoaDonThang) <> 12
        OR (SELECT COUNT(*) FROM dbo.ChiTietHoaDon) <> 60
        OR (SELECT COUNT(*) FROM dbo.LuongThang) <> 18
        THROW 51004, N'So hoa don, chi tiet hoac bang luong khong dung.', 1;

    DROP TABLE #Ky;
    DROP TABLE #Ngay;
    DROP TABLE #So;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT YEAR(logdv.NgaySuDung) AS Nam, MONTH(logdv.NgaySuDung) AS Thang,
    dv.MaLoaiDV, COUNT_BIG(*) AS SoLog,
    SUM(CONVERT(decimal(18,2), logdv.SoLuot) * logdv.DonGiaApDung) AS DoanhThu
FROM dbo.ChiTietSuDungNV AS logdv
JOIN dbo.DichVu AS dv ON dv.MaDichVu = logdv.MaDichVu
GROUP BY YEAR(logdv.NgaySuDung), MONTH(logdv.NgaySuDung), dv.MaLoaiDV
ORDER BY Nam, Thang, dv.MaLoaiDV;
GO