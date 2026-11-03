/* Kiem tra rieng pham vi seed TV3; du lieu ZH_ cua file test khong nam trong pham vi nay.
   Chay duoc sau test phan 4. Khong dung lai 03_Validate cua TV3 de dem 18 bang sau khi da them 5 bang.
*/
SET NOCOUNT ON;
IF (SELECT COUNT_BIG(*) FROM dbo.ChiTietSuDungNV c JOIN dbo.NhanVienCongTy n ON n.MaNVCT=c.MaNVCT
   JOIN dbo.DichVu d ON d.MaDichVu=c.MaDichVu
   WHERE n.MaCongTy IN('CT01','CT02','CT03','CT04','CT05','CT06') AND d.MaToaNha IN('TN01','TN02','TN03')
    AND c.NgaySuDung BETWEEN '20260801' AND '20260930')<>7320
 THROW 51620,N'Log seed TV3 da thay doi.',1;
IF (SELECT SUM(c.SoTien) FROM dbo.HoaDonThang h JOIN dbo.V_ChiTietHoaDon c ON c.MaHoaDon=h.MaHoaDon
   WHERE h.MaToaNha IN('TN01','TN02','TN03') AND h.Nam=2026 AND h.Thang IN(8,9))<>725400000
 THROW 51621,N'Tong hoa don seed TV3 da thay doi.',1;
IF (SELECT SUM(l.LuongCoBan+l.TienThuong) FROM dbo.LuongThang l
   JOIN dbo.NhanVienToaNha n ON n.MaNVTN=l.MaNVTN
   WHERE n.MaToaNha IN('TN01','TN02','TN03') AND l.Nam=2026 AND l.Thang IN(8,9))<>208137000
 THROW 51622,N'Tong luong seed TV3 da thay doi.',1;
SELECT N'PASS doi chieu seed TV3' AS KetQua;
GO

IF (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0 AND name<>'sysdiagrams')<>18
 THROW 51623,N'Phan 4 khong duoc tao them bang nghiep vu.',1;
GO
