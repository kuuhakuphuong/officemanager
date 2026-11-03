/*=============================================================================
  PHAN 5 — KIEM THU TRIGGER (TV5: Khuc Tuan Anh — CHHT001)
  File nay = 04_Triggers.sql ban giao cho TV6

  Quy uoc:
  - Du lieu test dung tien to ZH_ (giong TV4) de cach ly khoi seed TV3
  - Moi test case tach rieng trong BEGIN TRY..END CATCH
  - In ket qua PASS / FAIL ro rang, kem ma loi 55xxx
  - Test ca truong hop PASS (du lieu hop le) va FAIL (vi pham nghiep vu)
  - 15 test cases: 5.1(5) + 5.2(3) + 5.3(6) + 5.4(3) + 5.5(2)  [da bo sung TC06 cho 55305]
  ============================================================================= */
SET NOCOUNT ON;
GO

PRINT N'';
PRINT N'================================================================';
PRINT N'  KIEM THU TRIGGER — TV5 (Khuc Tuan Anh, CHHT001)';
PRINT N'================================================================';
PRINT N'';
GO

/* ============================================================================
   CHUAN BI DU LIEU TEST
   Tao du lieu nen voi tien to ZH_ (mot phan TV4 da tao, bo sung them)
   ============================================================================ */

/* Kiem tra du lieu ZH_ cua TV4 da ton tai (toa nha, cong ty, van phong co ban) */
IF NOT EXISTS (SELECT 1 FROM dbo.ToaNha WHERE MaToaNha = 'ZH_TN')
BEGIN
    INSERT dbo.ViTri(MaViTri, TenViTri, DonGiaThueM2)
    VALUES ('ZH_VT', N'ZH Vi Tri Test', 150000);

    INSERT dbo.ToaNha(MaToaNha, TenToaNha, DiaChi, SoTang)
    VALUES ('ZH_TN', N'ZH Toa Nha Test', N'123 Test Street', 10);

    INSERT dbo.VanPhong(MaVanPhong, MaToaNha, MaViTri, Tang, DienTich)
    VALUES ('ZH_VP1', 'ZH_TN', 'ZH_VT', 1, 80.00),
           ('ZH_VP2', 'ZH_TN', 'ZH_VT', 2, 120.00);

    INSERT dbo.CongTy(MaCongTy, TenCongTy, MaSoThue, DiaChi, LinhVuc)
    VALUES ('ZH_CT', N'ZH Cong Ty Test', '1234567890', N'456 Test Rd', N'CNTT');
END;

/* Bo sung them van phong va cong ty cho test */
IF NOT EXISTS (SELECT 1 FROM dbo.VanPhong WHERE MaVanPhong = 'ZH_VP3')
    INSERT dbo.VanPhong(MaVanPhong, MaToaNha, MaViTri, Tang, DienTich)
    VALUES ('ZH_VP3', 'ZH_TN', 'ZH_VT', 3, 50.00);

IF NOT EXISTS (SELECT 1 FROM dbo.CongTy WHERE MaCongTy = 'ZH_CT2')
    INSERT dbo.CongTy(MaCongTy, TenCongTy, MaSoThue, DiaChi, LinhVuc)
    VALUES ('ZH_CT2', N'ZH Cong Ty 2', '9876543210', N'789 Test Rd', N'Tai chinh');

/* Nhan vien cho ZH_CT */
IF NOT EXISTS (SELECT 1 FROM dbo.NhanVienCongTy WHERE MaNVCT = 'ZH_NV1')
    INSERT dbo.NhanVienCongTy(MaNVCT, MaCongTy, HoTen, GioiTinh, NgaySinh, ChucVu, NgayVaoLam)
    VALUES ('ZH_NV1', 'ZH_CT', N'Nguyen Van A', 'M', '1990-01-15', N'Nhan vien', '2020-01-01'),
           ('ZH_NV2', 'ZH_CT', N'Tran Thi B',   'F', '1992-03-20', N'Truong phong', '2020-01-01');

/* Nhan vien da nghi viec */
IF NOT EXISTS (SELECT 1 FROM dbo.NhanVienCongTy WHERE MaNVCT = 'ZH_NV3')
    INSERT dbo.NhanVienCongTy(MaNVCT, MaCongTy, HoTen, GioiTinh, NgaySinh, ChucVu, NgayVaoLam, NgayNghiViec)
    VALUES ('ZH_NV3', 'ZH_CT', N'Le Van C', 'M', '1988-05-10', N'Nhan vien', '2020-01-01', '2025-06-30');

/* Loai dich vu va dich vu test */
IF NOT EXISTS (SELECT 1 FROM dbo.LoaiDichVu WHERE MaLoaiDV = 'ZH_LDV_T')
BEGIN
    INSERT dbo.LoaiDichVu(MaLoaiDV, TenLoai, KieuTinhPhi, CoTinhTheoNguoi, CoTinhTheoDienTich)
    VALUES ('ZH_LDV_T', N'ZH Ve sinh (thang)', 'THANG', 1, 1),
           ('ZH_LDV_L', N'ZH Phong hop (luot)', 'LUOT', 0, 0);

    INSERT dbo.DichVu(MaDichVu, MaToaNha, MaLoaiDV, TenDichVu, DonGiaCoBan)
    VALUES ('ZH_DVT1', 'ZH_TN', 'ZH_LDV_T', N'ZH Dich vu ve sinh', 500000),
           ('ZH_DVL1', 'ZH_TN', 'ZH_LDV_L', N'ZH Phong hop A',     200000);
END;
GO

PRINT N'[CHUAN BI] Du lieu test ZH_ da san sang.';
PRINT N'';
GO


/* ============================================================================
   TEST 5.1  TR_ChiTietThue_ChanTrungLap
   ============================================================================ */
PRINT N'--- TEST 5.1: TR_ChiTietThue_ChanTrungLap ---';
GO

/* 5.1-TC01: INSERT hop dong hop le — PASS */
BEGIN TRY
    DELETE dbo.HopDongThue WHERE MaHopDong LIKE 'ZH_HD%';
    INSERT dbo.HopDongThue(MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc)
    VALUES ('ZH_HD1', 'ZH_CT', 'ZH_VP1', '2026-01-01', '2026-12-31');
    PRINT N'  5.1-TC01 PASS: INSERT hop dong hop le thanh cong.';
END TRY
BEGIN CATCH
    PRINT N'  5.1-TC01 FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.1-TC02: INSERT hop dong trung lich — FAIL expected (55101) */
BEGIN TRY
    INSERT dbo.HopDongThue(MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc)
    VALUES ('ZH_HD2', 'ZH_CT2', 'ZH_VP1', '2026-06-01', '2027-06-30');
    PRINT N'  5.1-TC02 FAIL: Da cho phep hop dong trung lich! (ky vong 55101)';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 55101
        PRINT N'  5.1-TC02 PASS: Chan dung trung lich — loi 55101.';
    ELSE
        PRINT N'  5.1-TC02 FAIL: Loi khong dung — ' + CAST(ERROR_NUMBER() AS varchar) + N': ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.1-TC03: INSERT hop dong KHAC van phong — PASS */
BEGIN TRY
    INSERT dbo.HopDongThue(MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc)
    VALUES ('ZH_HD3', 'ZH_CT2', 'ZH_VP2', '2026-06-01', '2027-06-30');
    PRINT N'  5.1-TC03 PASS: Van phong khac, khong trung lich.';
END TRY
BEGIN CATCH
    PRINT N'  5.1-TC03 FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.1-TC04: HD hien tai open-ended (NULL) + INSERT HD moi cung VP — FAIL expected (55101)
   Tam UPDATE ZH_HD1 thanh open-ended de test overlap voi HD khong co ngay ket thuc */
UPDATE dbo.HopDongThue SET NgayKetThuc = NULL WHERE MaHopDong = 'ZH_HD1';
GO
BEGIN TRY
    INSERT dbo.HopDongThue(MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc)
    VALUES ('ZH_HD4', 'ZH_CT2', 'ZH_VP1', '2028-01-01', '2028-12-31');
    PRINT N'  5.1-TC04 FAIL: Da cho phep trung lich voi HD open-ended! (ky vong 55101)';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 55101
        PRINT N'  5.1-TC04 PASS: Chan trung lich voi HD open-ended — loi 55101.';
    ELSE
        PRINT N'  5.1-TC04 FAIL: Loi khong dung — ' + CAST(ERROR_NUMBER() AS varchar) + N': ' + ERROR_MESSAGE();
END CATCH;
/* Restore ZH_HD1 ve NgayKetThuc ban dau de TC05 chay dung */
UPDATE dbo.HopDongThue SET NgayKetThuc = '2026-12-31' WHERE MaHopDong = 'ZH_HD1';
GO

/* 5.1-TC05: INSERT hop dong SAU khi HD cu ket thuc — PASS */
BEGIN TRY
    INSERT dbo.HopDongThue(MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc)
    VALUES ('ZH_HD5', 'ZH_CT2', 'ZH_VP1', '2027-01-01', '2027-12-31');
    PRINT N'  5.1-TC05 PASS: HD bat dau sau khi HD cu ket thuc.';
END TRY
BEGIN CATCH
    PRINT N'  5.1-TC05 FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT N'';
GO


/* ============================================================================
   TEST 5.2  TR_DangKyDichVu_ApDungBacThang
   ============================================================================ */
PRINT N'--- TEST 5.2: TR_DangKyDichVu_ApDungBacThang ---';
GO

/* 5.2-TC01: Dang ky DV THANG khi chua co hop dong thue — FAIL expected (55201) */
BEGIN TRY
    DELETE dbo.SuDungDichVu WHERE MaCongTy = 'ZH_CT2' AND MaDichVu = 'ZH_DVT1';
    /* ZH_CT2 co HD tai ZH_VP2 nhung khong tai ZH_VP1 cung toa nha -> co lease */
    /* Tao CT moi khong co lease */
    IF NOT EXISTS (SELECT 1 FROM dbo.CongTy WHERE MaCongTy = 'ZH_CT3')
        INSERT dbo.CongTy(MaCongTy, TenCongTy, MaSoThue, DiaChi, LinhVuc)
        VALUES ('ZH_CT3', N'ZH CT No Lease', '5555555555', N'No Lease Rd', N'Khac');

    INSERT dbo.SuDungDichVu(MaCongTy, MaDichVu, NgayBatDau, NgayKetThuc)
    VALUES ('ZH_CT3', 'ZH_DVT1', '2026-01-01', NULL);
    PRINT N'  5.2-TC01 FAIL: Cho phep DK dich vu khi chua co lease! (ky vong 55201)';
    DELETE dbo.SuDungDichVu WHERE MaCongTy = 'ZH_CT3' AND MaDichVu = 'ZH_DVT1';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 55201
        PRINT N'  5.2-TC01 PASS: Chan DK DV thang khi chua co lease — loi 55201.';
    ELSE
        PRINT N'  5.2-TC01 FAIL: Loi khong dung — ' + CAST(ERROR_NUMBER() AS varchar) + N': ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.2-TC02: Dang ky DV THANG khi CO hop dong thue — PASS + in bac gia */
BEGIN TRY
    DELETE dbo.SuDungDichVu WHERE MaCongTy = 'ZH_CT' AND MaDichVu = 'ZH_DVT1';
    INSERT dbo.SuDungDichVu(MaCongTy, MaDichVu, NgayBatDau, NgayKetThuc)
    VALUES ('ZH_CT', 'ZH_DVT1', '2026-01-01', NULL);
    PRINT N'  5.2-TC02 PASS: DK dich vu thang hop le. Thong tin bac gia in phia tren.';
END TRY
BEGIN CATCH
    PRINT N'  5.2-TC02 FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.2-TC03: Dang ky DV LUOT — PASS (trigger khong chan, khong tinh bac gia) */
BEGIN TRY
    DELETE dbo.SuDungDichVu WHERE MaCongTy = 'ZH_CT' AND MaDichVu = 'ZH_DVL1';
    INSERT dbo.SuDungDichVu(MaCongTy, MaDichVu, NgayBatDau, NgayKetThuc)
    VALUES ('ZH_CT', 'ZH_DVL1', '2026-01-01', NULL);
    PRINT N'  5.2-TC03 PASS: DK dich vu luot (khong tinh bac gia).';
END TRY
BEGIN CATCH
    PRINT N'  5.2-TC03 FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT N'';
GO


/* ============================================================================
   TEST 5.3  TR_NhatKyDichVu_KiemTraHopLe
   ============================================================================ */
PRINT N'--- TEST 5.3: TR_NhatKyDichVu_KiemTraHopLe ---';
GO

/* 5.3-TC01: Ghi nhat ky hop le — PASS */
BEGIN TRY
    DELETE dbo.ChiTietSuDungNV WHERE MaNVCT LIKE 'ZH_%';
    INSERT dbo.ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung)
    VALUES ('ZH_NV1', 'ZH_DVL1', CONVERT(date, GETDATE()), 1, 200000);
    PRINT N'  5.3-TC01 PASS: Ghi nhat ky hop le.';
END TRY
BEGIN CATCH
    PRINT N'  5.3-TC01 FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.3-TC02: Ngay su dung tuong lai — FAIL expected (55303) */
BEGIN TRY
    INSERT dbo.ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung)
    VALUES ('ZH_NV2', 'ZH_DVL1', DATEADD(day, 30, GETDATE()), 1, 200000);
    PRINT N'  5.3-TC02 FAIL: Cho phep ghi ngay tuong lai! (ky vong 55303)';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 55303
        PRINT N'  5.3-TC02 PASS: Chan ngay tuong lai — loi 55303.';
    ELSE
        PRINT N'  5.3-TC02 FAIL: Loi khong dung — ' + CAST(ERROR_NUMBER() AS varchar) + N': ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.3-TC03: NV da nghi viec — FAIL expected (55302) */
BEGIN TRY
    INSERT dbo.ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung)
    VALUES ('ZH_NV3', 'ZH_DVL1', CONVERT(date, GETDATE()), 1, 200000);
    PRINT N'  5.3-TC03 FAIL: Cho phep NV da nghi viec su dung! (ky vong 55302)';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 55302
        PRINT N'  5.3-TC03 PASS: Chan NV da nghi viec — loi 55302.';
    ELSE
        PRINT N'  5.3-TC03 FAIL: Loi khong dung — ' + CAST(ERROR_NUMBER() AS varchar) + N': ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.3-TC04: DV hang thang, khong phai LUOT — FAIL expected (55304) */
BEGIN TRY
    INSERT dbo.ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung)
    VALUES ('ZH_NV1', 'ZH_DVT1', CONVERT(date, GETDATE()), 1, 500000);
    PRINT N'  5.3-TC04 FAIL: Cho phep ghi nhat ky cho DV thang! (ky vong 55304)';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 55304
        PRINT N'  5.3-TC04 PASS: Chan ghi nhat ky DV thang — loi 55304.';
    ELSE
        PRINT N'  5.3-TC04 FAIL: Loi khong dung — ' + CAST(ERROR_NUMBER() AS varchar) + N': ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.3-TC05: Cong ty chua dang ky DV — FAIL expected (55301) */
BEGIN TRY
    /* ZH_CT2 chua dang ky ZH_DVL1 */
    IF NOT EXISTS (SELECT 1 FROM dbo.NhanVienCongTy WHERE MaNVCT = 'ZH_NV4')
        INSERT dbo.NhanVienCongTy(MaNVCT, MaCongTy, HoTen, GioiTinh, NgaySinh, ChucVu, NgayVaoLam)
        VALUES ('ZH_NV4', 'ZH_CT2', N'Pham Van D', 'M', '1993-07-07', N'Nhan vien', '2021-01-01');

    INSERT dbo.ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung)
    VALUES ('ZH_NV4', 'ZH_DVL1', CONVERT(date, GETDATE()), 1, 200000);
    PRINT N'  5.3-TC05 FAIL: Cho phep ghi khi CT chua DK DV! (ky vong 55301)';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 55301
        PRINT N'  5.3-TC05 PASS: Chan ghi khi CT chua DK DV — loi 55301.';
    ELSE
        PRINT N'  5.3-TC05 FAIL: Loi khong dung — ' + CAST(ERROR_NUMBER() AS varchar) + N': ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.3-TC06: CT co DK DV nhung KHONG co hop dong thue tai toa nha — FAIL expected (55305) */
BEGIN TRY
    IF NOT EXISTS (SELECT 1 FROM dbo.CongTy WHERE MaCongTy = 'ZH_CT5')
        INSERT dbo.CongTy(MaCongTy, TenCongTy, MaSoThue, DiaChi, LinhVuc)
        VALUES ('ZH_CT5', N'ZH CT No Lease 2', '7777777777', N'No Lease 2 Rd', N'Khac');

    IF NOT EXISTS (SELECT 1 FROM dbo.NhanVienCongTy WHERE MaNVCT = 'ZH_NV5')
        INSERT dbo.NhanVienCongTy(MaNVCT, MaCongTy, HoTen, GioiTinh, NgaySinh, ChucVu, NgayVaoLam)
        VALUES ('ZH_NV5', 'ZH_CT5', N'Vo Van E', 'M', '1991-02-14', N'Nhan vien', '2021-01-01');

    /* ZH_CT5 dang ky DV luot tai ZH_TN nhung KHONG co hop dong thue */
    DELETE dbo.SuDungDichVu WHERE MaCongTy = 'ZH_CT5' AND MaDichVu = 'ZH_DVL1';
    INSERT dbo.SuDungDichVu(MaCongTy, MaDichVu, NgayBatDau, NgayKetThuc)
    VALUES ('ZH_CT5', 'ZH_DVL1', '2020-01-01', NULL);

    INSERT dbo.ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung)
    VALUES ('ZH_NV5', 'ZH_DVL1', CONVERT(date, GETDATE()), 1, 200000);
    PRINT N'  5.3-TC06 FAIL: Cho phep ghi khi CT khong co HD thue tai toa nha! (ky vong 55305)';
    DELETE dbo.ChiTietSuDungNV WHERE MaNVCT = 'ZH_NV5';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 55305
        PRINT N'  5.3-TC06 PASS: Chan ghi khi CT khong co HD thue tai toa nha — loi 55305.';
    ELSE
        PRINT N'  5.3-TC06 FAIL: Loi khong dung — ' + CAST(ERROR_NUMBER() AS varchar) + N': ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT N'';
GO


/* ============================================================================
   TEST 5.4  TR_CongTy_ChanXoa + TR_ToaNha_ChanXoa
   ============================================================================ */
PRINT N'--- TEST 5.4: TR_CongTy_ChanXoa + TR_ToaNha_ChanXoa ---';
GO

/* 5.4-TC01: Xoa CongTy co du lieu phu thuoc — FAIL expected (55401) */
BEGIN TRY
    DELETE dbo.CongTy WHERE MaCongTy = 'ZH_CT';
    PRINT N'  5.4-TC01 FAIL: Cho phep xoa CT co NV va HD! (ky vong 55401)';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 55401
        PRINT N'  5.4-TC01 PASS: Chan xoa CT co phu thuoc — loi 55401.';
    ELSE
        PRINT N'  5.4-TC01 FAIL: Loi khong dung — ' + CAST(ERROR_NUMBER() AS varchar) + N': ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.4-TC02: Xoa ToaNha co du lieu phu thuoc — FAIL expected (55402) */
BEGIN TRY
    DELETE dbo.ToaNha WHERE MaToaNha = 'ZH_TN';
    PRINT N'  5.4-TC02 FAIL: Cho phep xoa TN co VP va DV! (ky vong 55402)';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 55402
        PRINT N'  5.4-TC02 PASS: Chan xoa TN co phu thuoc — loi 55402.';
    ELSE
        PRINT N'  5.4-TC02 FAIL: Loi khong dung — ' + CAST(ERROR_NUMBER() AS varchar) + N': ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.4-TC03: Xoa CongTy KHONG co phu thuoc — PASS */
BEGIN TRY
    IF NOT EXISTS (SELECT 1 FROM dbo.CongTy WHERE MaCongTy = 'ZH_CT_EMPTY')
        INSERT dbo.CongTy(MaCongTy, TenCongTy, MaSoThue, DiaChi, LinhVuc)
        VALUES ('ZH_CT_EMPTY', N'ZH CT Trong', '1111111111', N'Empty Rd', N'Khac');

    DELETE dbo.CongTy WHERE MaCongTy = 'ZH_CT_EMPTY';

    IF NOT EXISTS (SELECT 1 FROM dbo.CongTy WHERE MaCongTy = 'ZH_CT_EMPTY')
        PRINT N'  5.4-TC03 PASS: Xoa CT khong phu thuoc thanh cong.';
    ELSE
        PRINT N'  5.4-TC03 FAIL: CT van con ton tai sau khi xoa.';
END TRY
BEGIN CATCH
    PRINT N'  5.4-TC03 FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT N'';
GO


/* ============================================================================
   TEST 5.5  TR_ChiTietThue_DongBoDienTich
   ============================================================================ */
PRINT N'--- TEST 5.5: TR_ChiTietThue_DongBoDienTich ---';
GO

/* 5.5-TC01: INSERT hop dong → VanPhong.TrangThai = 'DANG_THUE' */
BEGIN TRY
    DECLARE @tt1 varchar(20);
    SELECT @tt1 = TrangThai FROM dbo.VanPhong WHERE MaVanPhong = 'ZH_VP3';
    PRINT N'  5.5-TC01 Truoc: ZH_VP3.TrangThai = ' + ISNULL(@tt1, N'NULL');

    /* ZH_VP3 chua co hop dong — insert mot cai */
    DELETE dbo.HopDongThue WHERE MaHopDong = 'ZH_HD_T55';
    INSERT dbo.HopDongThue(MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc)
    VALUES ('ZH_HD_T55', 'ZH_CT', 'ZH_VP3', '2025-01-01', '2027-12-31');

    SELECT @tt1 = TrangThai FROM dbo.VanPhong WHERE MaVanPhong = 'ZH_VP3';
    IF @tt1 = 'DANG_THUE'
        PRINT N'  5.5-TC01 PASS: VP chuyen sang DANG_THUE sau INSERT HD.';
    ELSE
        PRINT N'  5.5-TC01 FAIL: TrangThai = ' + ISNULL(@tt1, N'NULL') + N' (ky vong DANG_THUE)';
END TRY
BEGIN CATCH
    PRINT N'  5.5-TC01 FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.5-TC02: DELETE hop dong → VanPhong.TrangThai = 'TRONG' */
BEGIN TRY
    DELETE dbo.HopDongThue WHERE MaHopDong = 'ZH_HD_T55';

    DECLARE @tt2 varchar(20);
    SELECT @tt2 = TrangThai FROM dbo.VanPhong WHERE MaVanPhong = 'ZH_VP3';
    IF @tt2 = 'TRONG'
        PRINT N'  5.5-TC02 PASS: VP chuyen ve TRONG sau DELETE HD.';
    ELSE
        PRINT N'  5.5-TC02 FAIL: TrangThai = ' + ISNULL(@tt2, N'NULL') + N' (ky vong TRONG)';
END TRY
BEGIN CATCH
    PRINT N'  5.5-TC02 FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT N'';
GO


/* ============================================================================
   DON DEP DU LIEU TEST
   ============================================================================ */
PRINT N'--- DON DEP ---';
GO

/* Xoa theo thu tu phu thuoc de tranh bi Trigger 5.4 chan
   Bao gom ca cac bang TV4 co the chua du lieu ZH_
   Dung subquery an toan — tranh loi ten cot sai schema */
DELETE dbo.ChiTietSuDungNV  WHERE MaNVCT    LIKE 'ZH_%';
DELETE dbo.SuDungDichVu     WHERE MaCongTy  LIKE 'ZH_%';
/* ChiTietHoaDon -> HoaDonThang -> qua MaHopDong lien ket ZH_ */
DELETE dbo.ChiTietHoaDon    WHERE MaHoaDon IN (SELECT MaHoaDon FROM dbo.HoaDonThang WHERE MaCongTy LIKE 'ZH_%');
DELETE dbo.HoaDonThang      WHERE MaCongTy  LIKE 'ZH_%';
DELETE dbo.HopDongThue      WHERE MaHopDong LIKE 'ZH_HD%' OR MaCongTy LIKE 'ZH_%';
/* Cac bang TV4 — chi dung MaNVTN LIKE 'ZH_%' (an toan voi moi schema) */
IF OBJECT_ID('dbo.LuongThang','U') IS NOT NULL
    EXEC sp_executesql N'DELETE dbo.LuongThang WHERE MaNVTN LIKE ''ZH_%''';
IF OBJECT_ID('dbo.PhanCongNVTN','U') IS NOT NULL
    EXEC sp_executesql N'DELETE dbo.PhanCongNVTN WHERE MaNVTN LIKE ''ZH_%''';
IF OBJECT_ID('dbo.NhanVienToaNha','U') IS NOT NULL
    EXEC sp_executesql N'DELETE dbo.NhanVienToaNha WHERE MaNVTN LIKE ''ZH_%''';
DELETE dbo.NhanVienCongTy   WHERE MaNVCT    LIKE 'ZH_%';
IF OBJECT_ID('dbo.ChiPhiVanHanh','U') IS NOT NULL
    EXEC sp_executesql N'DELETE dbo.ChiPhiVanHanh WHERE MaToaNha LIKE ''ZH_%''';
DELETE dbo.DichVu           WHERE MaDichVu  LIKE 'ZH_%';
DELETE dbo.LoaiDichVu       WHERE MaLoaiDV  LIKE 'ZH_%';
DELETE dbo.VanPhong          WHERE MaVanPhong LIKE 'ZH_%';
DELETE dbo.CongTy           WHERE MaCongTy  LIKE 'ZH_%';
DELETE dbo.ToaNha           WHERE MaToaNha  LIKE 'ZH_%';
DELETE dbo.ViTri            WHERE MaViTri   LIKE 'ZH_%';
GO

PRINT N'[TV5] Don dep du lieu test ZH_ hoan tat.';
PRINT N'';
PRINT N'================================================================';
PRINT N'  KET THUC KIEM THU TRIGGER — TV5';
PRINT N'================================================================';
GO