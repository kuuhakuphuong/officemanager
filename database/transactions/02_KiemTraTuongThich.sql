SET NOCOUNT ON;
IF (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0 AND name<>'sysdiagrams')<>18
 THROW 51610,N'Can dung 18 bang nghiep vu cua DDL moi TV3.',1;
IF COL_LENGTH('dbo.ChiTietHoaDon','SoTien') IS NOT NULL OR OBJECT_ID('dbo.V_ChiTietHoaDon','V') IS NULL
 THROW 51611,N'Can schema moi: SoTien o view V_ChiTietHoaDon, khong o bang ChiTietHoaDon.',1;
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.HoaDonThang')
 AND name='MaHoaDon' AND TYPE_NAME(system_type_id)='int' AND is_identity=1)
 OR NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.ChiTietHoaDon')
 AND name='MaHoaDon' AND TYPE_NAME(system_type_id)='int')
 THROW 51612,N'MaHoaDon phai INT o ca bang cha va bang con.',1;
IF (SELECT COUNT(*) FROM dbo.ThamSo WHERE TenThamSo IN('NGUONG_NGUOI','BUOC_NGUOI',
 'NGUONG_DIEN_TICH','BUOC_DIEN_TICH','TY_LE_TANG_GIA'))<>5
 THROW 51613,N'Thieu bo ten tham so moi TV3.',1;
SELECT N'Khopp metadata chinh cua ban 18 bang moi' AS KetQua;
GO
