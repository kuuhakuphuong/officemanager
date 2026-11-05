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
        ('NGUONG_NGUOI', 10, N'Ngưỡng số người để tính bậc giá dịch vụ tháng'),
        ('BUOC_NGUOI', 5, N'Bước tăng số người cho mỗi bậc giá'),
        ('NGUONG_DIEN_TICH', 100, N'Ngưỡng diện tích (m2) để tính bậc giá'),
        ('BUOC_DIEN_TICH', 10, N'Bước tăng diện tích (m2) cho mỗi bậc'),
        ('TY_LE_TANG_GIA', 0.05, N'Tỷ lệ tăng giá cho mỗi bậc');

    INSERT dbo.ViTri(MaViTri, TenViTri, DonGiaThueM2) VALUES
        ('VT_TRONG', N'Khu vực trong nhà', 200000),
        ('VT_MAT_TIEN', N'Mặt tiền', 250000);

    INSERT dbo.LoaiDichVu(MaLoaiDV, TenLoai, KieuTinhPhi, CoTinhTheoNguoi, CoTinhTheoDienTich) VALUES
        ('AN_UONG', N'Ăn uống', 'LUOT', 0, 0),
        ('GUI_XE', N'Gửi xe', 'LUOT', 0, 0),
        ('VE_SINH', N'Vệ sinh văn phòng', 'THANG', 1, 1);

    INSERT dbo.BacCongViec(MaBac, TenBac, LuongCoBan, HeSoDoanhThu) VALUES
        ('BAC_QL', N'Quản lý tòa nhà', 18000000, 0),
        ('BAC_AN', N'Nhân viên nhà ăn', 8000000, 0.05),
        ('BAC_XE', N'Nhân viên bãi xe', 7500000, 0.04);

    INSERT dbo.ToaNha(MaToaNha, TenToaNha, DiaChi, SoTang) VALUES
        ('TN01', N'Tòa nhà Thăng Long Center', N'Số 10 Duy Tân, Cầu Giấy, Hà Nội', 9),
        ('TN02', N'Tòa nhà Sông Hàn Business', N'Số 120 Bạch Đằng, Hải Châu, Đà Nẵng', 10),
        ('TN03', N'Tòa nhà Sài Gòn Tower', N'Số 25 Lê Duẩn, Quận 1, TP. Hồ Chí Minh', 11);

    INSERT dbo.CongTy(MaCongTy, TenCongTy, MaSoThue, DiaChi, DienThoai, Email, LinhVuc) VALUES
        ('CT01', N'Công ty TNHH Giải pháp Phần mềm Thăng Long', '0109000001', N'Số 5 Phạm Hùng, Nam Từ Liêm, Hà Nội', '0243123401', 'contact@thanglongsoft.vn', N'Công nghệ thông tin'),
        ('CT02', N'Công ty Cổ phần Thương mại Hoàng Hà', '0109000002', N'Số 18 Nguyễn Chí Thanh, Đống Đa, Hà Nội', '0243123402', 'info@hoanghatrade.vn', N'Thương mại'),
        ('CT03', N'Công ty TNHH Tư vấn Tài chính Bình Minh', '0109000003', N'Số 9 Láng Hạ, Ba Đình, Hà Nội', '0243123403', 'hello@binhminhfin.vn', N'Tài chính'),
        ('CT04', N'Công ty Cổ phần Logistics Sông Hồng', '0109000004', N'Số 33 Trần Phú, Hà Đông, Hà Nội', '0243123404', 'sales@songhonglogistics.vn', N'Logistics'),
        ('CT05', N'Công ty TNHH Dược phẩm An Khang', '0109000005', N'Số 71 Hoàng Quốc Việt, Cầu Giấy, Hà Nội', '0243123405', 'cskh@ankhangpharma.vn', N'Dược phẩm'),
        ('CT06', N'Công ty Cổ phần Đầu tư Sao Mai', '0109000006', N'Số 2 Cầu Giấy, Ba Đình, Hà Nội', '0243123406', 'contact@saomai-invest.vn', N'Bất động sản');

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
        -- Họ tên ghép từ họ, đệm, tên theo giới tính (cùng quy tắc với bản MySQL).
        CONCAT(
            CHOOSE(So % 8 + 1, N'Nguyễn', N'Trần', N'Lê', N'Phạm', N'Hoàng', N'Vũ', N'Đặng', N'Bùi'), N' ',
            CASE WHEN So % 2 = 0 THEN CHOOSE(So % 5 + 1, N'Thị', N'Ngọc', N'Thu', N'Kim', N'Phương')
                ELSE CHOOSE(So % 5 + 1, N'Văn', N'Đức', N'Quốc', N'Minh', N'Hữu') END, N' ',
            CASE WHEN So % 2 = 0 THEN CHOOSE((So * 3) % 10 + 1, N'Lan', N'Hoa', N'Mai', N'Linh', N'Hương', N'Trang', N'Nga', N'Thảo', N'Yến', N'Ngân')
                ELSE CHOOSE((So * 3) % 10 + 1, N'Anh', N'Hùng', N'Dũng', N'Khoa', N'Long', N'Tuấn', N'Nam', N'Sơn', N'Đạt', N'Hiếu') END),
        CASE WHEN So % 2 = 0 THEN 'F' ELSE 'M' END,
        DATEADD(day, So * 17, CONVERT(date, '19900101')),
        CONCAT('09100000', RIGHT(CONCAT('00', So), 2)), CONCAT('employee', So, '@example.com'),
        CHOOSE(So % 3 + 1, N'Chuyên viên', N'Nhân viên kinh doanh', N'Kế toán viên'), '20260701', NULL
    FROM #So WHERE So BETWEEN 1 AND 60;

    INSERT dbo.DichVu(MaDichVu, MaToaNha, MaLoaiDV, TenDichVu, DonGiaCoBan)
    SELECT CONCAT(loai.TienTo, RIGHT(toanha.MaToaNha, 2)), toanha.MaToaNha,
        loai.MaLoaiDV, CONCAT(loai.Ten, N' - ', toanha.TenToaNha), loai.DonGia
    FROM dbo.ToaNha AS toanha
    CROSS JOIN (VALUES
        ('AN', 'AN_UONG', N'Bữa trưa', CONVERT(decimal(18,2), 35000)),
        ('XE', 'GUI_XE', N'Gửi xe máy', CONVERT(decimal(18,2), 5000)),
        ('VS', 'VE_SINH', N'Vệ sinh', CONVERT(decimal(18,2), 1500000))
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
        GioiTinh, NgaySinh, DienThoai, Email, NgayVaoLam) VALUES
        ('QL01', 'TN01', NULL, 'QUAN_LY', N'Nguyễn Hoàng Long', 'M', '1985-01-01', '0912000001', 'quanly.thanglong@example.com', '2026-01-01'),
        ('QL02', 'TN02', NULL, 'QUAN_LY', N'Phạm Đức Thắng', 'M', '1983-05-14', '0912000002', 'quanly.songhan@example.com', '2026-01-01'),
        ('QL03', 'TN03', NULL, 'QUAN_LY', N'Lê Thị Ngọc Anh', 'F', '1987-09-02', '0912000003', 'quanly.saigon@example.com', '2026-01-01');

    INSERT dbo.NhanVienToaNha(MaNVTN, MaToaNha, MaQuanLy, LoaiNV, HoTen,
        GioiTinh, NgaySinh, DienThoai, Email, NgayVaoLam) VALUES
        ('NVAN01', 'TN01', 'QL01', 'DICH_VU', N'Hoàng Thị Lan', 'F', '1992-01-01', NULL, 'lan.hoang@example.com', '2026-01-01'),
        ('NVXE01', 'TN01', 'QL01', 'DICH_VU', N'Vũ Minh Khoa', 'M', '1992-01-01', NULL, 'khoa.vu@example.com', '2026-01-01'),
        ('NVAN02', 'TN02', 'QL02', 'DICH_VU', N'Đặng Thị Thu Hiền', 'F', '1992-01-01', NULL, 'hien.dang@example.com', '2026-01-01'),
        ('NVXE02', 'TN02', 'QL02', 'DICH_VU', N'Bùi Quốc Bảo', 'M', '1992-01-01', NULL, 'bao.bui@example.com', '2026-01-01'),
        ('NVAN03', 'TN03', 'QL03', 'DICH_VU', N'Trần Thị Ngọc Yến', 'F', '1992-01-01', NULL, 'yen.tran@example.com', '2026-01-01'),
        ('NVXE03', 'TN03', 'QL03', 'DICH_VU', N'Nguyễn Văn Tâm', 'M', '1992-01-01', NULL, 'tam.nguyen@example.com', '2026-01-01');

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
        NguoiThu = N'Nguyễn Thị Thu Hà'
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
        CONCAT(N'Chi phí vận hành tháng ', ky.Thang, '/', ky.Nam)
    FROM dbo.ToaNha AS tn CROSS JOIN #Ky AS ky
    CROSS JOIN (VALUES (N'Điện nước', 12000000), (N'Bảo trì', 5000000), (N'Vật tư', 3000000)) AS chiphi(Loai, Tien);

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