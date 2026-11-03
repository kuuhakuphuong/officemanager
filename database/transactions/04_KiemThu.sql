/* CHI CHAY TREN BAN SAO THU NGHIEM CO DDL + SEED TV3. KHONG CHAY CSDL NHOM DANG NHAP LIEU.
   Can 18 bang dung 01_CreateSchema.sql TV3, 00_TaoKieuDuLieu.sql va 03_Transactions.sql.
   Du lieu test thang 08 va 09/2026; chi chay sau 30/09/2026.
   Script co COMMIT de cac procedure tu so huu transaction. Khong boc ngoai bang BEGIN TRAN.
   Khong tu xoa du lieu sau test; bo CSDL thu nghiem khi khong con can.
   Loi THROW 599xx = test khong dat; ket qua PASS chi xuat hien khi SQL Server chay test thuc.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF DB_NAME() IN ('master','model','msdb','tempdb')
 THROW 59900,N'Hay chon CSDL thu nghiem rieng.',1;
IF CONVERT(date,GETDATE())<='20260930' THROW 59900,N'Chua ket thuc ky du lieu mau.',1;
IF EXISTS(SELECT 1 FROM dbo.ToaNha WHERE MaToaNha='ZH_TN')
 THROW 59900,N'Bo test da ton tai. Tao lai CSDL thu nghiem rong de chay lai.',1;
IF (SELECT COUNT(*) FROM dbo.ThamSo WHERE
 (TenThamSo='NGUONG_NGUOI' AND GiaTri=10) OR
 (TenThamSo='BUOC_NGUOI' AND GiaTri=5) OR
 (TenThamSo='NGUONG_DIEN_TICH' AND GiaTri=100) OR
 (TenThamSo='BUOC_DIEN_TICH' AND GiaTri=10) OR
 (TenThamSo='TY_LE_TANG_GIA' AND GiaTri=0.05))<>5
 THROW 59900,N'Can nam tham so nhu seed TV3. Khong tu ghi de tham so.',1;
GO
BEGIN TRY
 BEGIN TRANSACTION;
 INSERT dbo.ViTri VALUES('ZH_VT','Vi tri test',200000);
 INSERT dbo.BacCongViec VALUES('ZH_B1','Bac test 1',5000000,0.05),('ZH_B2','Bac test 2',6000000,0.04),('ZH_QL','Quan ly',10000000,0);
 INSERT dbo.ToaNha VALUES('ZH_TN','Toa nha test','Dia chi test',5);
 -- TV6 sửa: chỉ định cột để chạy được sau khi TV5 thêm VanPhong.TrangThai.
 INSERT dbo.VanPhong(MaVanPhong,MaToaNha,MaViTri,Tang,DienTich)
 VALUES('ZH_P1','ZH_TN','ZH_VT',1,80),('ZH_P2','ZH_TN','ZH_VT',1,30);
 INSERT dbo.CongTy VALUES('ZH_CT','Cong ty test','0109999988','Dia chi test',NULL,NULL,'Test');
 INSERT dbo.LoaiDichVu VALUES('ZH_THANG','Dich vu thang','THANG',1,1),('ZH_LUOT','Dich vu luot','LUOT',0,0);
 INSERT dbo.DichVu(MaDichVu,MaToaNha,MaLoaiDV,TenDichVu,DonGiaCoBan)
 VALUES('ZH_VS','ZH_TN','ZH_THANG','Ve sinh test',1000000),('ZH_AU','ZH_TN','ZH_LUOT','An uong test',25000);
 INSERT dbo.NhanVienCongTy(MaNVCT,MaCongTy,HoTen,GioiTinh,NgaySinh,DienThoai,Email,ChucVu,NgayVaoLam,NgayNghiViec)
 SELECT 'ZH_NV'+RIGHT('00'+CONVERT(varchar(2),n),2),'ZH_CT','Nhan vien test','M','20000101',NULL,NULL,'Test','20260701',NULL
 FROM(VALUES(1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) v(n);
 INSERT dbo.SuDungDichVu VALUES('ZH_CT','ZH_VS','20260801','20260930'),('ZH_CT','ZH_AU','20260801','20260930');
 INSERT dbo.NhanVienToaNha(MaNVTN,MaToaNha,MaQuanLy,LoaiNV,HoTen,GioiTinh,NgaySinh,DienThoai,Email,NgayVaoLam)
 VALUES('ZH_QL1','ZH_TN',NULL,'QUAN_LY','Quan ly test','M','19900101',NULL,NULL,'20260701');
 INSERT dbo.NhanVienToaNha(MaNVTN,MaToaNha,MaQuanLy,LoaiNV,HoTen,GioiTinh,NgaySinh,DienThoai,Email,NgayVaoLam)
 VALUES('ZH_DV1','ZH_TN','ZH_QL1','DICH_VU','NV test 1','M','20000101',NULL,NULL,'20260701'),
 ('ZH_DV2','ZH_TN','ZH_QL1','DICH_VU','NV test 2','F','20000101',NULL,NULL,'20260701');
 INSERT dbo.PhanCongNVTN SELECT n.MaNVTN,m.Thang,2026,n.MaDV,n.MaBac
 FROM(VALUES('ZH_QL1',CAST(NULL AS varchar(10)),'ZH_QL'),('ZH_DV1','ZH_VS','ZH_B1'),('ZH_DV2','ZH_AU','ZH_B2'))
 n(MaNVTN,MaDV,MaBac) CROSS JOIN(VALUES(8),(9)) m(Thang);
 COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO
-- Chu dong phat loi sau INSERT de kiem tra rollback that cua T1.
CREATE OR ALTER TRIGGER dbo.Test_TV4_ChanThue ON dbo.HopDongThue AFTER INSERT AS
BEGIN
 IF EXISTS(SELECT 1 FROM inserted WHERE MaVanPhong='ZH_P2') THROW 59099,N'Loi test sau khi INSERT phong.',1;
END;
GO
BEGIN TRY
 DECLARE @P dbo.TT_DanhSachPhong;
 INSERT @P VALUES('ZH_P1'),('ZH_P2');
 BEGIN TRY
  EXEC dbo.USP_Trx_KyHopDongThueMatBang 'ZH_CT','ZH_TN','20260801','20260930',@P;
  THROW 59930,N'Loi gia lap khong duoc kich hoat.',1;
 END TRY
 BEGIN CATCH
  IF ERROR_NUMBER()<>59099 THROW;
 END CATCH;
 IF EXISTS(SELECT 1 FROM dbo.HopDongThue WHERE MaCongTy='ZH_CT') OR @@TRANCOUNT<>0
  THROW 59931,N'Rollback T1 khong tron ven.',1;
 DROP TRIGGER dbo.Test_TV4_ChanThue;
 PRINT 'PASS rollback T1 sau INSERT';
END TRY
BEGIN CATCH
 IF OBJECT_ID('dbo.Test_TV4_ChanThue','TR') IS NOT NULL DROP TRIGGER dbo.Test_TV4_ChanThue;
 THROW;
END CATCH;
GO
-- T1 thanh cong: mot giao dich, hai dong thue trong bang goc; khong co hop dong cha.
DECLARE @P dbo.TT_DanhSachPhong;
INSERT @P VALUES('ZH_P1'),('ZH_P2');
EXEC dbo.USP_Trx_KyHopDongThueMatBang 'ZH_CT','ZH_TN','20260801','20260930',@P;
IF (SELECT COUNT(*) FROM dbo.HopDongThue WHERE MaCongTy='ZH_CT')<>2
 THROW 59901,N'T1 khong tao du hai phong.',1;
PRINT 'PASS T1 - Ky nhieu phong';
GO
-- T1 tu choi chong lich va khong luu header thua.
DECLARE @P dbo.TT_DanhSachPhong;
INSERT @P VALUES('ZH_P1');
BEGIN TRY
 EXEC dbo.USP_Trx_KyHopDongThueMatBang 'ZH_CT','ZH_TN','20260815','20261001',@P;
 THROW 59902,N'T1 da chap nhan thue trung.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51106 THROW;
END CATCH;
IF (SELECT COUNT(*) FROM dbo.HopDongThue WHERE MaCongTy='ZH_CT')<>2
 THROW 59903,N'T1 de lai them dong thue sau loi.',1;
PRINT 'PASS T1 - Chan chong lich';
GO
-- T2 lo sai mot dong: toan bo lo phai bi tu choi.
DECLARE @X dbo.TT_DanhSachSuDung;
INSERT @X VALUES('ZH_NV01','ZH_AU','20260801',1),('KHONG_CO','ZH_AU','20260801',1);
BEGIN TRY
 EXEC dbo.USP_Trx_GhiNhanDichVuHangNgay @X;
 THROW 59904,N'T2 chap nhan nhan vien khong ton tai.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51202 THROW;
END CATCH;
IF EXISTS(SELECT 1 FROM dbo.ChiTietSuDungNV WHERE MaDichVu='ZH_AU')
 THROW 59905,N'T2 da ghi mot phan lo sai.',1;
PRINT 'PASS T2 - Tu choi ca lo sai';
GO
DECLARE @X dbo.TT_DanhSachSuDung;
INSERT @X VALUES('ZH_NV01','ZH_AU','20260801',1),('ZH_NV01','ZH_AU','20260802',4),
 ('ZH_NV01','ZH_AU','20260901',1),('ZH_NV01','ZH_AU','20260902',4);
EXEC dbo.USP_Trx_GhiNhanDichVuHangNgay @X;
IF (SELECT COUNT(*) FROM dbo.ChiTietSuDungNV WHERE MaDichVu='ZH_AU')<>4
 THROW 59906,N'T2 khong ghi du bon dong.',1;
BEGIN TRY
 EXEC dbo.USP_Trx_GhiNhanDichVuHangNgay @X;
 THROW 59907,N'T2 chap nhan lo trung.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51204 THROW;
END CATCH;
PRINT 'PASS T2 - Ghi lo va chan trung';
GO
-- T5 truoc khi chot hoa don phai loi.
BEGIN TRY
 EXEC dbo.USP_Trx_ChotBangLuongNhanVien 'ZH_TN',8,2026;
 THROW 59908,N'T5 tinh luong truoc hoa don.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51502 THROW;
END CATCH;
PRINT 'PASS T5 - Bat buoc chot hoa don truoc';
GO
EXEC dbo.USP_Trx_PhatHanhHoaDonThang 'ZH_TN',8,2026;
EXEC dbo.USP_Trx_PhatHanhHoaDonThang 'ZH_TN',9,2026;
IF (SELECT COUNT(*) FROM dbo.HoaDonThang WHERE MaToaNha='ZH_TN')<>2
 THROW 59909,N'T3 khong tao dung hai hoa don.',1;
IF EXISTS(SELECT 1 FROM dbo.HoaDonThang h JOIN dbo.V_ChiTietHoaDon c ON c.MaHoaDon=h.MaHoaDon
 WHERE h.MaToaNha='ZH_TN' GROUP BY h.MaHoaDon HAVING SUM(c.SoTien)<>23175000)
 THROW 59910,N'T3 sai tong tien: 22000000 + 1050000 + 125000.',1;
IF EXISTS(SELECT 1 FROM dbo.V_ChiTietHoaDon c JOIN dbo.HoaDonThang h ON h.MaHoaDon=c.MaHoaDon
 WHERE h.MaToaNha='ZH_TN' AND c.SoTien<>ROUND(c.SoLuong*c.DonGiaApDung*c.TyLeNgay,2))
 THROW 59911,N'T3 snapshot khong khop cong thuc.',1;
BEGIN TRY
 EXEC dbo.USP_Trx_PhatHanhHoaDonThang 'ZH_TN',8,2026;
 THROW 59912,N'T3 lap trung hoa don.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51304 THROW;
END CATCH;
PRINT 'PASS T3 - Hai thang, tong tien, snapshot, chan lap trung';
GO
DECLARE @X dbo.TT_DanhSachSuDung;
INSERT @X VALUES('ZH_NV02','ZH_AU','20260803',1);
BEGIN TRY
 EXEC dbo.USP_Trx_GhiNhanDichVuHangNgay @X;
 THROW 59913,N'T2 them duoc log vao ky da chot.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51203 THROW;
END CATCH;
PRINT 'PASS T2 - Chan thay doi ky da chot';
GO
-- T4 kiem thu nghiep vu thanh toan hoa don tron goi:
DECLARE @HD int=(SELECT MaHoaDon FROM dbo.HoaDonThang WHERE MaToaNha='ZH_TN' AND Thang=8 AND Nam=2026),
 @YC uniqueidentifier=NEWID(),@Ngay date=CONVERT(date,GETDATE());

-- Ca 1 (Am tinh): Sai so tien thanh toan -> chan boi loi 51406
BEGIN TRY
 EXEC dbo.USP_Trx_ThanhToanHoaDonVaVaoSoQuy @HD,10000000,@Ngay,N'ThuNgan01',@YC;
 THROW 59914,N'T4 cho phep thanh toan sai so tien.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51406 THROW;
END CATCH;

-- Ca 2 (Duong tinh): Thanh toan dung 100% tong tien hoa don (23,175,000 VND)
EXEC dbo.USP_Trx_ThanhToanHoaDonVaVaoSoQuy @HD,23175000,@Ngay,N'ThuNgan01',@YC;

-- Kiem tra trang thai hoa don da duoc cap nhat
IF NOT EXISTS(SELECT 1 FROM dbo.HoaDonThang WHERE MaHoaDon=@HD AND TrangThai='DA_THANH_TOAN' AND NgayThanhToan=@Ngay AND NguoiThu=N'ThuNgan01')
 THROW 59915,N'T4 khong cap nhat dung trang thai DA_THANH_TOAN.',1;

-- Ca 3 (Chong thanh toan trung): Goi lai tren hoa don da thanh toan -> chan boi loi 51403
BEGIN TRY
 EXEC dbo.USP_Trx_ThanhToanHoaDonVaVaoSoQuy @HD,23175000,@Ngay,N'ThuNgan01',@YC;
 THROW 59916,N'T4 cho phep thanh toan trung lap tren hoa don da thanh toan.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51403 THROW;
END CATCH;
PRINT 'PASS T4 - Thanh toan thanh cong, chan sai tien, chan thanh toan trung lap';
GO
EXEC dbo.USP_Trx_ChotBangLuongNhanVien 'ZH_TN',8,2026;
EXEC dbo.USP_Trx_ChotBangLuongNhanVien 'ZH_TN',9,2026;
IF (SELECT COUNT(*) FROM dbo.LuongThang WHERE MaNVTN IN('ZH_DV1','ZH_DV2','ZH_QL1'))<>6
 THROW 59920,N'T5 khong tao du luong hai thang.',1;
IF EXISTS(SELECT 1 FROM dbo.LuongThang WHERE MaNVTN='ZH_DV1' AND TienThuong<>52500)
 OR EXISTS(SELECT 1 FROM dbo.LuongThang WHERE MaNVTN='ZH_DV2' AND TienThuong<>5000)
 OR EXISTS(SELECT 1 FROM dbo.LuongThang WHERE MaNVTN='ZH_QL1' AND TienThuong<>0)
 THROW 59922,N'T5 sai thuong theo ty le HeSoDoanhThu cua TV3.',1;
BEGIN TRY
 EXEC dbo.USP_Trx_ChotBangLuongNhanVien 'ZH_TN',8,2026;
 THROW 59923,N'T5 tinh trung luong.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51503 THROW;
END CATCH;
IF @@TRANCOUNT<>0 THROW 59924,N'Test de lai transaction chua dong.',1;
PRINT 'PASS T5 - Thuong theo ty le TV3, quan ly 0 thuong, chan trung luong';
-- TV6 sửa: T4 đã có ca kiểm thử thanh toán đủ một lần ở trên.
PRINT 'HOAN THANH TEST T1,T2,T3,T4,T5; T4 KHONG CO PHIEU THU DOC LAP';
GO
