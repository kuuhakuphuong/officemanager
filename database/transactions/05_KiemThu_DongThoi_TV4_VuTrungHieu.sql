/* Chi doc. Runner -DongThoi dung 2 ket noi thue cung ZH_P3.
   Co the thu cong mo 2 cua so SSMS va cung goi T1 voi cung phong chua thue.
   Mot lenh thanh cong, lenh kia loi 51106; neu timeout khoa, loi 51001.
   Chua duoc ket luan da test dong thoi khi chua chay SQL Server. */
SELECT a.MaHopDong,b.MaHopDong,a.MaVanPhong
FROM dbo.HopDongThue a JOIN dbo.HopDongThue b
 ON a.MaVanPhong=b.MaVanPhong AND a.MaHopDong<b.MaHopDong
WHERE a.NgayBatDau<=ISNULL(b.NgayKetThuc,CONVERT(date,'99991231'))
 AND b.NgayBatDau<=ISNULL(a.NgayKetThuc,CONVERT(date,'99991231'));
SELECT MaCongTy,MaToaNha,Thang,Nam,COUNT(*) AS SoHoaDon
FROM dbo.HoaDonThang GROUP BY MaCongTy,MaToaNha,Thang,Nam HAVING COUNT(*)>1;
GO
