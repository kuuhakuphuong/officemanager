USE QLToaNha_BCNF;
GO
SET NOCOUNT ON;
SET XACT_ABORT OFF;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

PRINT N'STAGE: structural and seed checks';
IF NOT EXISTS (SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.HoaDonThang') AND name = N'TrangThai'
        AND system_type_id = TYPE_ID(N'varchar') AND max_length = 20 AND is_nullable = 0)
    OR NOT EXISTS (SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.HoaDonThang') AND name = N'NgayThanhToan'
            AND system_type_id = TYPE_ID(N'date') AND is_nullable = 1)
    OR NOT EXISTS (SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.HoaDonThang') AND name = N'NguoiThu'
            AND system_type_id = TYPE_ID(N'nvarchar') AND max_length = 200 AND is_nullable = 1)
    OR NOT EXISTS (SELECT 1 FROM sys.default_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.HoaDonThang')
            AND parent_column_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.HoaDonThang'), N'TrangThai', 'ColumnId')
            AND name = N'DF_HoaDon_TrangThai' AND definition = '(''CHUA_THANH_TOAN'')')
    OR NOT EXISTS (SELECT 1 FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.HoaDonThang') AND name = N'CK_HoaDonThang_ThanhToan'
            AND is_disabled = 0 AND is_not_trusted = 0)
    THROW 51114, N'Thieu/sai cot, DEFAULT hoac CHECK thanh toan; chay script 05.', 1;
IF (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0 AND name <> 'sysdiagrams') <> 18
    THROW 51100, N'Khong du 18 bang nghiep vu.', 1;
IF OBJECT_ID(N'dbo.V_ChiTietHoaDon', N'V') IS NULL
    OR COL_LENGTH(N'dbo.ChiTietHoaDon', N'SoTien') IS NOT NULL
    OR (SELECT TYPE_NAME(user_type_id) FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.HoaDonThang') AND name = N'MaHoaDon') <> N'int'
    OR (SELECT TYPE_NAME(user_type_id) FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.ChiTietHoaDon') AND name = N'MaHoaDon') <> N'int'
    OR NOT EXISTS (SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.HoaDonThang') AND name = N'MaHoaDon' AND is_identity = 1)
    THROW 51113, N'Sai kieu MaHoaDon hoac view V_ChiTietHoaDon.', 1;
IF (SELECT COUNT(*) FROM sys.key_constraints WHERE type = 'PK' AND parent_object_id <> ISNULL(OBJECT_ID('dbo.sysdiagrams'), 0)) <> 18
    THROW 51101, N'Khong du 18 PK.', 1;
IF (SELECT COUNT(*) FROM sys.foreign_keys) <> 23
    THROW 51102, N'Khong du 23 FK.', 1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE is_disabled = 1 OR is_not_trusted = 1)
    OR EXISTS (SELECT 1 FROM sys.check_constraints WHERE is_disabled = 1 OR is_not_trusted = 1)
    THROW 51103, N'Co FK/CHECK bi tat hoac khong trusted.', 1;
IF EXISTS (
    SELECT 1 FROM sys.tables AS tbl
    WHERE tbl.is_ms_shipped = 0 AND tbl.name <> 'sysdiagrams'
        AND NOT EXISTS (SELECT 1 FROM sys.partitions AS part
            WHERE part.object_id = tbl.object_id AND part.index_id IN (0, 1) AND part.rows > 0)
)
    THROW 51104, N'Co bang chua duoc nap du lieu.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.ChiTietSuDungNV) <> 7320
    OR (SELECT MIN(NgaySuDung) FROM dbo.ChiTietSuDungNV) <> '20260801'
    OR (SELECT MAX(NgaySuDung) FROM dbo.ChiTietSuDungNV) <> '20260930'
    OR (SELECT COUNT(DISTINCT NgaySuDung) FROM dbo.ChiTietSuDungNV) <> 61
    THROW 51105, N'Sai khoi luong hoac khoang thoi gian log.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.ChiTietSuDungNV AS logdv
    JOIN dbo.NhanVienCongTy AS nv ON nv.MaNVCT = logdv.MaNVCT
    JOIN dbo.DichVu AS dv ON dv.MaDichVu = logdv.MaDichVu
    JOIN dbo.LoaiDichVu AS loai ON loai.MaLoaiDV = dv.MaLoaiDV
    WHERE loai.KieuTinhPhi <> 'LUOT' OR logdv.DonGiaApDung <> dv.DonGiaCoBan
        OR logdv.NgaySuDung < nv.NgayVaoLam
        OR (nv.NgayNghiViec IS NOT NULL AND logdv.NgaySuDung > nv.NgayNghiViec)
        OR NOT EXISTS (SELECT 1 FROM dbo.SuDungDichVu AS dk
            WHERE dk.MaCongTy = nv.MaCongTy AND dk.MaDichVu = logdv.MaDichVu
                AND logdv.NgaySuDung >= dk.NgayBatDau
                AND (dk.NgayKetThuc IS NULL OR logdv.NgaySuDung <= dk.NgayKetThuc))
        OR NOT EXISTS (SELECT 1 FROM dbo.HopDongThue AS hd
            JOIN dbo.VanPhong AS vp ON vp.MaVanPhong = hd.MaVanPhong
            WHERE hd.MaCongTy = nv.MaCongTy AND vp.MaToaNha = dv.MaToaNha
                AND logdv.NgaySuDung >= hd.NgayBatDau
                AND (hd.NgayKetThuc IS NULL OR logdv.NgaySuDung <= hd.NgayKetThuc))
)
    THROW 51106, N'Log khong khop dang ky, hop dong, gia hoac thoi gian lam viec.', 1;

IF EXISTS (SELECT 1 FROM dbo.VanPhong AS vp JOIN dbo.ToaNha AS tn ON tn.MaToaNha = vp.MaToaNha WHERE vp.Tang > tn.SoTang)
    OR EXISTS (SELECT 1 FROM dbo.NhanVienToaNha AS nv JOIN dbo.NhanVienToaNha AS ql ON ql.MaNVTN = nv.MaQuanLy
        WHERE nv.MaToaNha <> ql.MaToaNha OR ql.LoaiNV <> 'QUAN_LY')
    OR EXISTS (SELECT 1 FROM dbo.PhanCongNVTN AS pc JOIN dbo.NhanVienToaNha AS nv ON nv.MaNVTN = pc.MaNVTN
        LEFT JOIN dbo.DichVu AS dv ON dv.MaDichVu = pc.MaDichVu
        WHERE (nv.LoaiNV = 'QUAN_LY' AND pc.MaDichVu IS NOT NULL)
            OR (nv.LoaiNV = 'DICH_VU' AND (pc.MaDichVu IS NULL OR nv.MaToaNha <> dv.MaToaNha)))
    THROW 51107, N'Sai tang hoac phan cong/quan ly khac toa nha.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.HopDongThue AS hd1 JOIN dbo.HopDongThue AS hd2
        ON hd1.MaVanPhong = hd2.MaVanPhong AND hd1.MaHopDong < hd2.MaHopDong
    WHERE hd1.NgayBatDau <= ISNULL(hd2.NgayKetThuc, CONVERT(date, '99991231'))
        AND hd2.NgayBatDau <= ISNULL(hd1.NgayKetThuc, CONVERT(date, '99991231'))
) OR EXISTS (
    SELECT 1 FROM dbo.SuDungDichVu AS dk1 JOIN dbo.SuDungDichVu AS dk2
        ON dk1.MaCongTy = dk2.MaCongTy AND dk1.MaDichVu = dk2.MaDichVu AND dk1.NgayBatDau < dk2.NgayBatDau
    WHERE dk2.NgayBatDau <= ISNULL(dk1.NgayKetThuc, CONVERT(date, '99991231'))
)
    THROW 51108, N'Co khoang thoi gian hop dong/dang ky chong nhau.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.HoaDonThang AS hd
    OUTER APPLY (
        SELECT SUM(CONVERT(decimal(18,2), logdv.SoLuot) * logdv.DonGiaApDung) AS TongLog
        FROM dbo.ChiTietSuDungNV AS logdv
        JOIN dbo.NhanVienCongTy AS nv ON nv.MaNVCT = logdv.MaNVCT
        JOIN dbo.DichVu AS dv ON dv.MaDichVu = logdv.MaDichVu
        WHERE nv.MaCongTy = hd.MaCongTy AND dv.MaToaNha = hd.MaToaNha
            AND YEAR(logdv.NgaySuDung) = hd.Nam AND MONTH(logdv.NgaySuDung) = hd.Thang
    ) AS logtong
    OUTER APPLY (
        SELECT SUM(ct.SoTien) AS TongDong FROM dbo.V_ChiTietHoaDon AS ct
        WHERE ct.MaHoaDon = hd.MaHoaDon AND ct.LoaiKhoan = 'DICH_VU_LUOT'
    ) AS dongtong
    WHERE ISNULL(logtong.TongLog, -1) <> ISNULL(dongtong.TongDong, -2)
)
    THROW 51109, N'Tien dich vu theo luot tren hoa don khong khop log.', 1;

IF (SELECT SUM(SoTien) FROM dbo.V_ChiTietHoaDon) <> 725400000
    OR (SELECT SUM(LuongCoBan + TienThuong) FROM dbo.LuongThang) <> 208137000
    THROW 51110, N'Tong hoa don hoac luong khong khop bo du lieu mau.', 1;

PRINT N'STAGE: negative constraint tests';
DECLARE @Cases TABLE (
    CaseID int IDENTITY(1,1) PRIMARY KEY,
    Ten varchar(100) NOT NULL,
    CauLenh nvarchar(max) NOT NULL,
    MaLoi int NOT NULL,
    DoiTuong nvarchar(128) NOT NULL
);
INSERT @Cases(Ten, CauLenh, MaLoi, DoiTuong) VALUES
('PK', N'INSERT dbo.ToaNha VALUES (''TN01'',N''Trung PK'',N''Mau'',5);', 2627, N'PK_ToaNha'),
-- TV6 sửa: chỉ định cột Văn phòng để ca FK không phụ thuộc cột trạng thái TV5.
('FK', N'INSERT dbo.VanPhong(MaVanPhong,MaToaNha,MaViTri,Tang,DienTich) VALUES (''TEST'',''MISSING'',''VT_TRONG'',1,80);', 547, N'FK_VanPhong_ToaNha'),
('NOT NULL', N'UPDATE dbo.CongTy SET MaSoThue = NULL WHERE MaCongTy = ''CT01'';', 515, N'MaSoThue'),
('UNIQUE MST', N'UPDATE dbo.CongTy SET MaSoThue = ''0109000001'' WHERE MaCongTy = ''CT02'';', 2627, N'UQ_CongTy_MaSoThue'),
('MST letters', N'UPDATE dbo.CongTy SET MaSoThue = ''010900000A'' WHERE MaCongTy = ''CT01'';', 547, N'CK_CongTy_MST'),
('MST short', N'UPDATE dbo.CongTy SET MaSoThue = ''123456789'' WHERE MaCongTy = ''CT01'';', 547, N'CK_CongTy_MST'),
('MST trailing space', N'UPDATE dbo.CongTy SET MaSoThue = ''123456789 '' WHERE MaCongTy = ''CT01'';', 547, N'CK_CongTy_MST'),
('MST branch letters', N'UPDATE dbo.CongTy SET MaSoThue = ''0109000001-00A'' WHERE MaCongTy = ''CT01'';', 547, N'CK_CongTy_MST'),
('Area zero', N'UPDATE dbo.VanPhong SET DienTich = 0 WHERE MaVanPhong = ''VP01'';', 547, N'CK_VanPhong_DienTich'),
('Area negative', N'UPDATE dbo.VanPhong SET DienTich = -1 WHERE MaVanPhong = ''VP01'';', 547, N'CK_VanPhong_DienTich'),
-- TV6 sửa: cùng ngày là hợp lệ; chỉ kiểm tra khoảng ngày đảo ngược trong bảng lỗi.
('Lease reversed dates', N'UPDATE dbo.HopDongThue SET NgayKetThuc = DATEADD(day,-1,NgayBatDau) WHERE MaHopDong = ''HD01'';', 547, N'CK_HopDongThue_Ngay'),
('Service reversed dates', N'UPDATE dbo.SuDungDichVu SET NgayKetThuc = DATEADD(day,-1,NgayBatDau) WHERE MaCongTy = ''CT01'';', 547, N'CK_SuDungDichVu_Ngay'),
('Service base price zero', N'UPDATE dbo.DichVu SET DonGiaCoBan = 0 WHERE MaDichVu = ''AN01'';', 547, N'CK_DichVu_DonGia'),
('Headcount zero', N'UPDATE dbo.ThamSo SET GiaTri = 0 WHERE TenThamSo = ''NGUONG_NGUOI'';', 547, N'CK_ThamSo_SoNguoi'),
('Headcount fractional', N'UPDATE dbo.ThamSo SET GiaTri = 1.5 WHERE TenThamSo = ''BUOC_NGUOI'';', 547, N'CK_ThamSo_SoNguoi'),
('Visits zero', N'UPDATE dbo.ChiTietSuDungNV SET SoLuot = 0 WHERE MaSuDung = (SELECT MIN(MaSuDung) FROM dbo.ChiTietSuDungNV);', 547, N'CK_ChiTietSuDungNV_SoLuot'),
('Price negative', N'UPDATE dbo.ChiTietSuDungNV SET DonGiaApDung = -1 WHERE MaSuDung = (SELECT MIN(MaSuDung) FROM dbo.ChiTietSuDungNV);', 547, N'CK_ChiTietSuDungNV_DonGia'),
('Invoice XOR both', N'UPDATE dbo.ChiTietHoaDon SET MaDichVu = ''AN01'' WHERE MaChiTiet = (SELECT MIN(MaChiTiet) FROM dbo.ChiTietHoaDon WHERE LoaiKhoan = ''THUE_VAN_PHONG'');', 547, N'CK_ChiTietHoaDon_Loai'),
('Invoice XOR neither', N'UPDATE dbo.ChiTietHoaDon SET MaVanPhong = NULL WHERE MaChiTiet = (SELECT MIN(MaChiTiet) FROM dbo.ChiTietHoaDon WHERE LoaiKhoan = ''THUE_VAN_PHONG'');', 547, N'CK_ChiTietHoaDon_Loai'),
('Invoice ratio', N'UPDATE dbo.ChiTietHoaDon SET TyLeNgay = 1.1 WHERE MaChiTiet = (SELECT MIN(MaChiTiet) FROM dbo.ChiTietHoaDon);', 547, N'CK_ChiTietHoaDon_TyLe'),
('Month invalid', N'UPDATE dbo.PhanCongNVTN SET Thang = 13 WHERE MaNVTN = ''QL01'';', 547, N'CK_PhanCongNVTN_Thang'),
('Composite payroll FK', N'INSERT dbo.LuongThang VALUES (''QL01'',7,2026,18000000,0);', 547, N'FK_LuongThang_PhanCong'),
('Manager self-reference', N'UPDATE dbo.NhanVienToaNha SET MaQuanLy = MaNVTN WHERE MaNVTN = ''NVAN01'';', 547, N'CK_NhanVienToaNha_QuanLy'),
('Unique daily log', N'INSERT dbo.ChiTietSuDungNV(MaNVCT,MaDichVu,NgaySuDung,DonGiaApDung) SELECT TOP(1) MaNVCT,MaDichVu,NgaySuDung,DonGiaApDung FROM dbo.ChiTietSuDungNV;', 2627, N'UQ_ChiTietSuDungNV_Ngay'),
('Unique invoice period', N'INSERT dbo.HoaDonThang(MaCongTy,MaToaNha,Thang,Nam) VALUES (''CT01'',''TN01'',8,2026);', 2627, N'UQ_HoaDonThang_Ky'),
('Payment invalid status', N'UPDATE dbo.HoaDonThang SET TrangThai = ''INVALID'';', 547, N'CK_HoaDonThang_ThanhToan'),
('Payment NULL status', N'UPDATE dbo.HoaDonThang SET TrangThai = NULL;', 515, N'TrangThai'),
('Payment missing date', N'UPDATE dbo.HoaDonThang SET TrangThai = ''DA_THANH_TOAN'', NgayThanhToan = NULL;', 547, N'CK_HoaDonThang_ThanhToan'),
('Payment unpaid with date', N'UPDATE dbo.HoaDonThang SET TrangThai = ''CHUA_THANH_TOAN'', NgayThanhToan = NgayLap, NguoiThu = NULL;', 547, N'CK_HoaDonThang_ThanhToan'),
('Payment before invoice', N'UPDATE dbo.HoaDonThang SET TrangThai = ''DA_THANH_TOAN'', NgayThanhToan = DATEADD(day,-1,NgayLap);', 547, N'CK_HoaDonThang_ThanhToan'),
('Payment unpaid collector', N'UPDATE dbo.HoaDonThang SET TrangThai = ''CHUA_THANH_TOAN'', NgayThanhToan = NULL, NguoiThu = N''Cashier'';', 547, N'CK_HoaDonThang_ThanhToan'),
('Payment blank collector', N'UPDATE dbo.HoaDonThang SET TrangThai = ''DA_THANH_TOAN'', NgayThanhToan = NgayLap, NguoiThu = N''   '';', 547, N'CK_HoaDonThang_ThanhToan');

DECLARE @CaseID int = 1, @Ten varchar(100), @Sql nvarchar(max), @Expected int, @Object nvarchar(128),
    @Actual int, @Message nvarchar(4000), @Failure nvarchar(2048);
WHILE @CaseID <= (SELECT COUNT(*) FROM @Cases)
BEGIN
    SELECT @Ten = Ten, @Sql = CauLenh, @Expected = MaLoi, @Object = DoiTuong FROM @Cases WHERE CaseID = @CaseID;
    SELECT @Actual = 0, @Message = N'';
    BEGIN TRANSACTION;
    BEGIN TRY
        EXEC sys.sp_executesql @Sql;
    END TRY
    BEGIN CATCH
        SELECT @Actual = ERROR_NUMBER(), @Message = ERROR_MESSAGE();
    END CATCH;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF @Actual <> @Expected OR CHARINDEX(@Object, @Message) = 0
    BEGIN
        SET @Failure = CONCAT(N'FAIL ', @Ten, N': expected ', @Expected, N' / ', @Object, N'; actual ', @Actual, N' / ', @Message);
        THROW 51111, @Failure, 1;
    END;
    PRINT CONCAT('PASS: ', @Ten);
    SET @CaseID += 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.HoaDonThang(MaCongTy, MaToaNha, Thang, Nam)
    VALUES ('CT01', 'TN01', 1, 1900);
    DECLARE @PaymentTestID int = SCOPE_IDENTITY();
    IF NOT EXISTS (SELECT 1 FROM dbo.HoaDonThang WHERE MaHoaDon = @PaymentTestID
        AND TrangThai = 'CHUA_THANH_TOAN' AND NgayThanhToan IS NULL AND NguoiThu IS NULL)
        THROW 51115, N'DEFAULT thanh toan khong dung.', 1;
    UPDATE dbo.HoaDonThang SET TrangThai = 'DA_THANH_TOAN', NgayThanhToan = NgayLap,
        NguoiThu = N'Test cashier' WHERE MaHoaDon = @PaymentTestID;
    UPDATE dbo.HoaDonThang SET NguoiThu = NULL WHERE MaHoaDon = @PaymentTestID;
    UPDATE dbo.HoaDonThang SET TrangThai = 'CHUA_THANH_TOAN', NgayThanhToan = NULL
        WHERE MaHoaDon = @PaymentTestID;
    PRINT N'PASS: payment DEFAULT, paid with/without collector, reset to unpaid (rolled back)';
    UPDATE dbo.CongTy SET MaSoThue = '0109000001-001' WHERE MaCongTy = 'CT01';
    -- TV6 sửa: ba trường hợp cùng ngày phải được chấp nhận; toàn bộ thay đổi sẽ rollback.
    UPDATE dbo.HopDongThue SET NgayKetThuc = NgayBatDau WHERE MaHopDong = 'HD01';
    UPDATE dbo.SuDungDichVu SET NgayKetThuc = NgayBatDau WHERE MaCongTy = 'CT01';
    UPDATE dbo.NhanVienCongTy SET NgayNghiViec = NgayVaoLam WHERE MaNVCT = 'NVCT001';
    UPDATE dbo.HopDongThue SET NgayKetThuc = NULL WHERE MaHopDong = 'HD01';
    INSERT dbo.ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, DonGiaApDung)
    VALUES ('NVCT001', 'AN01', '20261001', 35000);
    IF NOT EXISTS (SELECT 1 FROM dbo.ChiTietSuDungNV
        WHERE MaNVCT = 'NVCT001' AND MaDichVu = 'AN01' AND NgaySuDung = '20261001' AND SoLuot = 1)
        THROW 51112, N'DEFAULT SoLuot khong hoat dong.', 1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
DBCC CHECKDB(N'QLToaNha_BCNF') WITH NO_INFOMSGS;

SELECT tbl.name AS TenBang, SUM(part.rows) AS SoDong
FROM sys.tables AS tbl JOIN sys.partitions AS part ON part.object_id = tbl.object_id AND part.index_id IN (0, 1)
WHERE tbl.is_ms_shipped = 0 AND tbl.name <> 'sysdiagrams'
GROUP BY tbl.name ORDER BY tbl.name;
SELECT N'PASS: 18 tables, 23 FK, data reconciliation, 32 negative cases, payment structure and positive/default cases' AS KetQua;
GO
