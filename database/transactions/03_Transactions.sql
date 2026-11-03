/* VU TRUNG HIEU CHHT035 - BAN GIU DUNG 18 BANG, CAP NHAT THANH TOAN T4
   Can DDL MOI: MaHoaDon INT, SoTien chi co trong dbo.V_ChiTietHoaDon.
   Chay 00_TaoKieuDuLieu.sql truoc; khong tao bang nghiep vu bo sung.
   T1,T2,T3,T4,T5 co ma nghiep vu day du (T4 ho tro thanh toan tron goi 1 lan tren HoaDonThang).
*/
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.USP_Trx_KyHopDongThueMatBang
 @MaCongTy varchar(20), @MaToaNha varchar(20),
 @NgayBatDau date, @NgayKetThuc date,
 @DanhSachPhong dbo.TT_DanhSachPhong READONLY
AS
BEGIN
 SET NOCOUNT ON;
 IF @@TRANCOUNT<>0 THROW 51000,N'Goi thu tuc ngoai transaction cua ung dung.',1;
 SET XACT_ABORT ON;
 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Khoa int;
  EXEC @Khoa=sys.sp_getapplock @Resource=N'TV4_NghiepVu',@LockMode='Exclusive',
    @LockOwner='Transaction',@LockTimeout=10000;
  IF @Khoa<0 THROW 51001,N'Khong lay duoc khoa nghiep vu.',1;
  -- TV6 sửa: giao dịch thuê chấp nhận ngày kết thúc bằng ngày bắt đầu như DDL TV3.
  IF @NgayBatDau IS NULL OR (@NgayKetThuc IS NOT NULL AND @NgayKetThuc<@NgayBatDau)
    OR NOT EXISTS(SELECT 1 FROM @DanhSachPhong)
   THROW 51101,N'Ngay thue hoac danh sach phong khong hop le.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.CongTy WHERE MaCongTy=@MaCongTy)
    OR NOT EXISTS(SELECT 1 FROM dbo.ToaNha WHERE MaToaNha=@MaToaNha)
   THROW 51102,N'Cong ty hoac toa nha khong ton tai.',1;
  IF EXISTS(SELECT 1 FROM @DanhSachPhong p LEFT JOIN dbo.VanPhong v ON v.MaVanPhong=p.MaVanPhong
    WHERE v.MaVanPhong IS NULL OR v.MaToaNha<>@MaToaNha)
   THROW 51103,N'Phong phai ton tai va thuoc dung toa nha.',1;
  IF EXISTS(SELECT 1 FROM dbo.HoaDonThang h WHERE h.MaToaNha=@MaToaNha
    AND DATEFROMPARTS(h.Nam,h.Thang,1)<=ISNULL(@NgayKetThuc,CONVERT(date,'99991231'))
    AND EOMONTH(DATEFROMPARTS(h.Nam,h.Thang,1))>=@NgayBatDau)
   THROW 51105,N'Khoang thue cham vao ky da co hoa don.',1;
  IF EXISTS(SELECT 1 FROM @DanhSachPhong p JOIN dbo.HopDongThue h WITH(UPDLOCK,HOLDLOCK)
    ON h.MaVanPhong=p.MaVanPhong
    WHERE h.NgayBatDau<=ISNULL(@NgayKetThuc,CONVERT(date,'99991231'))
    AND ISNULL(h.NgayKetThuc,CONVERT(date,'99991231'))>=@NgayBatDau)
   THROW 51106,N'Co phong trung lich thue. Huy toan bo lo.',1;
  DECLARE @Ma TABLE(MaVanPhong varchar(20) PRIMARY KEY,MaHopDong varchar(20) NOT NULL UNIQUE);
  INSERT @Ma SELECT MaVanPhong,'H'+LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),19)
   FROM @DanhSachPhong;
  /* Tao ma rieng cho tung dong thue; PK van chan neu ngau nhien trung ma. */
  INSERT dbo.HopDongThue(MaHopDong,MaCongTy,MaVanPhong,NgayBatDau,NgayKetThuc)
   SELECT MaHopDong,@MaCongTy,MaVanPhong,@NgayBatDau,@NgayKetThuc FROM @Ma;
  COMMIT;
  SELECT MaHopDong,MaVanPhong FROM @Ma ORDER BY MaVanPhong;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.USP_Trx_GhiNhanDichVuHangNgay
 @DanhSach dbo.TT_DanhSachSuDung READONLY
AS
BEGIN
 SET NOCOUNT ON;
 SET ANSI_PADDING ON;
 SET ANSI_WARNINGS ON;
 SET ARITHABORT ON;
 SET CONCAT_NULL_YIELDS_NULL ON;
 SET NUMERIC_ROUNDABORT OFF;
 IF @@TRANCOUNT<>0 THROW 51000,N'Hay goi thu tuc ngoai transaction cua ung dung.',1;
 SET XACT_ABORT ON;
 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Khoa int;
  EXEC @Khoa=sys.sp_getapplock @Resource=N'TV4_NghiepVu',
    @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @Khoa<0 THROW 51001,N'Khong lay duoc khoa nghiep vu. Thu lai sau.',1;
  IF NOT EXISTS(SELECT 1 FROM @DanhSach)
    OR EXISTS(SELECT 1 FROM @DanhSach WHERE SoLuot<=0 OR NgaySuDung>CONVERT(date,GETDATE()))
   THROW 51201,N'Lo rong, so luot khong duong hoac ngay su dung trong tuong lai.',1;
  IF EXISTS(SELECT 1 FROM @DanhSach x
    LEFT JOIN dbo.NhanVienCongTy n ON n.MaNVCT=x.MaNVCT
    LEFT JOIN dbo.DichVu d ON d.MaDichVu=x.MaDichVu
    LEFT JOIN dbo.LoaiDichVu l ON l.MaLoaiDV=d.MaLoaiDV
    WHERE n.MaNVCT IS NULL OR d.MaDichVu IS NULL OR l.KieuTinhPhi<>'LUOT'
      OR x.NgaySuDung<n.NgayVaoLam OR x.NgaySuDung>ISNULL(n.NgayNghiViec,CONVERT(date,'99991231'))
      OR NOT EXISTS(SELECT 1 FROM dbo.SuDungDichVu s WHERE s.MaCongTy=n.MaCongTy
        AND s.MaDichVu=x.MaDichVu AND s.NgayBatDau<=x.NgaySuDung
        AND ISNULL(s.NgayKetThuc,CONVERT(date,'99991231'))>=x.NgaySuDung)
      OR NOT EXISTS(SELECT 1 FROM dbo.HopDongThue h JOIN dbo.VanPhong v
        ON v.MaVanPhong=h.MaVanPhong WHERE h.MaCongTy=n.MaCongTy AND v.MaToaNha=d.MaToaNha
        AND h.NgayBatDau<=x.NgaySuDung
        AND ISNULL(h.NgayKetThuc,CONVERT(date,'99991231'))>=x.NgaySuDung))
   THROW 51202,N'Nhan vien, dich vu, dang ky hoac hop dong khong hop le vao ngay su dung.',1;
  IF EXISTS(SELECT 1 FROM @DanhSach x JOIN dbo.DichVu d ON d.MaDichVu=x.MaDichVu
    JOIN dbo.HoaDonThang k ON k.MaToaNha=d.MaToaNha
      AND k.Thang=MONTH(x.NgaySuDung) AND k.Nam=YEAR(x.NgaySuDung))
   THROW 51203,N'Khong them nhat ky vao ky da phat hanh hoa don.',1;
  IF EXISTS(SELECT 1 FROM @DanhSach x JOIN dbo.ChiTietSuDungNV c WITH(UPDLOCK,HOLDLOCK)
    ON c.MaNVCT=x.MaNVCT AND c.MaDichVu=x.MaDichVu AND c.NgaySuDung=x.NgaySuDung)
   THROW 51204,N'Lo co nhat ky da duoc ghi nhan. Khong cong don ngam.',1;
  INSERT dbo.ChiTietSuDungNV(MaNVCT,MaDichVu,NgaySuDung,SoLuot,DonGiaApDung)
   SELECT x.MaNVCT,x.MaDichVu,x.NgaySuDung,x.SoLuot,d.DonGiaCoBan
   FROM @DanhSach x JOIN dbo.DichVu d ON d.MaDichVu=x.MaDichVu;
  DECLARE @SoDong int=@@ROWCOUNT;
  COMMIT;
  SELECT @SoDong AS SoDongDaGhi;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.USP_Trx_PhatHanhHoaDonThang
 @MaToaNha varchar(20), @Thang tinyint, @Nam smallint
AS
BEGIN
 SET NOCOUNT ON;
 SET ANSI_PADDING ON;
 SET ANSI_WARNINGS ON;
 SET ARITHABORT ON;
 SET CONCAT_NULL_YIELDS_NULL ON;
 SET NUMERIC_ROUNDABORT OFF;
 IF @@TRANCOUNT<>0 THROW 51000,N'Hay goi thu tuc ngoai transaction cua ung dung.',1;
 SET XACT_ABORT ON;
 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Khoa int;
  EXEC @Khoa=sys.sp_getapplock @Resource=N'TV4_NghiepVu',
    @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @Khoa<0 THROW 51001,N'Khong lay duoc khoa nghiep vu. Thu lai sau.',1;
  IF @Thang IS NULL OR @Thang NOT BETWEEN 1 AND 12 OR @Nam IS NULL OR @Nam NOT BETWEEN 1900 AND 9999
   THROW 51301,N'Thang hoac nam khong hop le.',1;
  DECLARE @Tu date=DATEFROMPARTS(@Nam,@Thang,1),@Den date=EOMONTH(DATEFROMPARTS(@Nam,@Thang,1));
  IF @Den>=CONVERT(date,GETDATE()) THROW 51302,N'Chi chot khi thang da ket thuc.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.ToaNha WHERE MaToaNha=@MaToaNha)
   THROW 51303,N'Toa nha khong ton tai.',1;
  IF EXISTS(SELECT 1 FROM dbo.HoaDonThang WITH(UPDLOCK,HOLDLOCK)
    WHERE MaToaNha=@MaToaNha AND Thang=@Thang AND Nam=@Nam)
   THROW 51304,N'Ky da co hoa don. Khong ghi de hoac lap bo sung ngam.',1;
  DECLARE @NguongNguoi decimal(18,6),@BuocNguoi decimal(18,6),
    @NguongDT decimal(18,6),@BuocDT decimal(18,6),@TyLe decimal(18,6);
  SELECT @NguongNguoi=MAX(CASE WHEN TenThamSo='NGUONG_NGUOI' THEN GiaTri END),
    @BuocNguoi=MAX(CASE WHEN TenThamSo='BUOC_NGUOI' THEN GiaTri END),
    @NguongDT=MAX(CASE WHEN TenThamSo='NGUONG_DIEN_TICH' THEN GiaTri END),
    @BuocDT=MAX(CASE WHEN TenThamSo='BUOC_DIEN_TICH' THEN GiaTri END),
    @TyLe=MAX(CASE WHEN TenThamSo='TY_LE_TANG_GIA' THEN GiaTri END)
   FROM dbo.ThamSo;
  IF @NguongNguoi IS NULL OR @BuocNguoi IS NULL OR @NguongDT IS NULL OR @BuocDT IS NULL OR @TyLe IS NULL
    OR @NguongNguoi<1 OR @BuocNguoi<=0 OR @NguongDT<0 OR @BuocDT<=0 OR @TyLe NOT BETWEEN 0 AND 1
    OR @NguongNguoi<>FLOOR(@NguongNguoi) OR @BuocNguoi<>FLOOR(@BuocNguoi)
   THROW 51305,N'Thieu hoac sai tham so bac thang.',1;
  /* Kiem tra du lieu nguon chong lich; khong de double-count khi trigger chua co. */
  IF EXISTS(SELECT 1 FROM dbo.HopDongThue a JOIN dbo.HopDongThue b
    ON a.MaVanPhong=b.MaVanPhong AND a.MaHopDong<b.MaHopDong
    JOIN dbo.VanPhong v ON v.MaVanPhong=a.MaVanPhong
    WHERE v.MaToaNha=@MaToaNha AND a.NgayBatDau<=@Den AND b.NgayBatDau<=@Den
      AND ISNULL(a.NgayKetThuc,CONVERT(date,'99991231'))>=@Tu
      AND ISNULL(b.NgayKetThuc,CONVERT(date,'99991231'))>=@Tu
      AND a.NgayBatDau<=ISNULL(b.NgayKetThuc,CONVERT(date,'99991231'))
      AND b.NgayBatDau<=ISNULL(a.NgayKetThuc,CONVERT(date,'99991231')))
   THROW 51306,N'Du lieu nguon co hop dong chong lich.',1;
  CREATE TABLE #Ngay(Ngay date NOT NULL PRIMARY KEY);
  ;WITH n AS(SELECT @Tu AS Ngay UNION ALL SELECT DATEADD(day,1,Ngay) FROM n WHERE Ngay<@Den)
   INSERT #Ngay SELECT Ngay FROM n OPTION(MAXRECURSION 31);
  CREATE TABLE #Dong(
   MaCongTy varchar(20) NOT NULL,LoaiKhoan varchar(20) NOT NULL,
   MaVanPhong varchar(20) NULL,MaDichVu varchar(20) NULL,
   SoLuong decimal(12,2) NOT NULL,DonGiaApDung decimal(18,2) NOT NULL,
   TyLeNgay decimal(12,10) NOT NULL
  );
  /* Tien thue: moi ngay thuoc hop dong duoc tinh ca ngay dau va ngay cuoi. */
  INSERT #Dong(MaCongTy,LoaiKhoan,MaVanPhong,MaDichVu,SoLuong,DonGiaApDung,TyLeNgay)
   SELECT h.MaCongTy,'THUE_VAN_PHONG',v.MaVanPhong,NULL,v.DienTich,t.DonGiaThueM2,
    CAST(COUNT(*)*1.0/DAY(@Den) AS decimal(12,10))
   FROM dbo.HopDongThue h JOIN dbo.VanPhong v ON v.MaVanPhong=h.MaVanPhong
   JOIN dbo.ViTri t ON t.MaViTri=v.MaViTri JOIN #Ngay n ON h.NgayBatDau<=n.Ngay
     AND ISNULL(h.NgayKetThuc,CONVERT(date,'99991231'))>=n.Ngay
   WHERE v.MaToaNha=@MaToaNha
   GROUP BY h.MaCongTy,v.MaVanPhong,v.DienTich,t.DonGiaThueM2;
  /* So nguoi tinh tren cong ty; dien tich tinh rieng toa nha, theo tung ngay.
     Theo seed TV3: <=10 nguoi=0 bac, (10,15]=1 bac, (15,20]=2 bac.
     Dien tich <=100=0 bac; (100,110]=1 bac; (110,120]=2 bac.
     Cong don bac nguoi va dien tich; khong lay MAX hai bac. */
  ;WITH sd AS(
   SELECT DISTINCT s.MaCongTy,s.MaDichVu,n.Ngay
   FROM dbo.SuDungDichVu s JOIN dbo.DichVu d ON d.MaDichVu=s.MaDichVu
   JOIN dbo.LoaiDichVu l ON l.MaLoaiDV=d.MaLoaiDV
   JOIN #Ngay n ON s.NgayBatDau<=n.Ngay AND ISNULL(s.NgayKetThuc,CONVERT(date,'99991231'))>=n.Ngay
   WHERE d.MaToaNha=@MaToaNha AND l.KieuTinhPhi='THANG'
  )
  SELECT sd.MaCongTy,sd.MaDichVu,sd.Ngay,
   CAST(ROUND(CAST(d.DonGiaCoBan AS decimal(18,2))*CAST(1+@TyLe*CAST((
    CASE WHEN l.CoTinhTheoNguoi=1 AND ng.SoNguoi>@NguongNguoi
      THEN CEILING((ng.SoNguoi-@NguongNguoi)/@BuocNguoi) ELSE 0 END
    +CASE WHEN l.CoTinhTheoDienTich=1 AND dt.DienTich>@NguongDT
      THEN CEILING((dt.DienTich-@NguongDT)/@BuocDT) ELSE 0 END) AS decimal(18,2))
      AS decimal(18,6)),2) AS decimal(18,2)) AS DonGia,
   dt.DienTich
  INTO #PhiNgay FROM sd JOIN dbo.DichVu d ON d.MaDichVu=sd.MaDichVu
   JOIN dbo.LoaiDichVu l ON l.MaLoaiDV=d.MaLoaiDV
   CROSS APPLY(SELECT COUNT(*) AS SoNguoi FROM dbo.NhanVienCongTy nv
    WHERE nv.MaCongTy=sd.MaCongTy AND nv.NgayVaoLam<=sd.Ngay
      AND ISNULL(nv.NgayNghiViec,CONVERT(date,'99991231'))>=sd.Ngay) ng
   CROSS APPLY(SELECT CAST(SUM(v.DienTich) AS decimal(18,2)) AS DienTich FROM dbo.HopDongThue h
    JOIN dbo.VanPhong v ON v.MaVanPhong=h.MaVanPhong
    WHERE h.MaCongTy=sd.MaCongTy AND v.MaToaNha=@MaToaNha AND h.NgayBatDau<=sd.Ngay
      AND ISNULL(h.NgayKetThuc,CONVERT(date,'99991231'))>=sd.Ngay) dt;
  IF EXISTS(SELECT 1 FROM #PhiNgay WHERE DienTich IS NULL)
   THROW 51307,N'Dang ky dich vu thang co ngay khong co hop dong thue cung toa.',1;
  INSERT #Dong(MaCongTy,LoaiKhoan,MaVanPhong,MaDichVu,SoLuong,DonGiaApDung,TyLeNgay)
   SELECT MaCongTy,'DICH_VU_THANG',NULL,MaDichVu,1,DonGia,
    CAST(COUNT(*)*1.0/DAY(@Den) AS decimal(12,10))
   FROM #PhiNgay GROUP BY MaCongTy,MaDichVu,DonGia;
  /* Nhom theo don gia lich su; khong lay gia hien tai de tinh lai nhat ky. */
  INSERT #Dong(MaCongTy,LoaiKhoan,MaVanPhong,MaDichVu,SoLuong,DonGiaApDung,TyLeNgay)
   SELECT nv.MaCongTy,'DICH_VU_LUOT',NULL,c.MaDichVu,SUM(CONVERT(bigint,c.SoLuot)),c.DonGiaApDung,1
   FROM dbo.ChiTietSuDungNV c JOIN dbo.NhanVienCongTy nv ON nv.MaNVCT=c.MaNVCT
   JOIN dbo.DichVu d ON d.MaDichVu=c.MaDichVu
   WHERE d.MaToaNha=@MaToaNha AND c.NgaySuDung BETWEEN @Tu AND @Den
   GROUP BY nv.MaCongTy,c.MaDichVu,c.DonGiaApDung;
  IF NOT EXISTS(SELECT 1 FROM #Dong) THROW 51308,N'Ky khong co khoan thu de lap hoa don.',1;
  DECLARE @HD TABLE(MaHoaDon int NOT NULL,MaCongTy varchar(20) NOT NULL PRIMARY KEY);
  INSERT dbo.HoaDonThang(MaCongTy,MaToaNha,Thang,Nam,NgayLap)
   OUTPUT inserted.MaHoaDon,inserted.MaCongTy INTO @HD
   SELECT DISTINCT MaCongTy,@MaToaNha,@Thang,@Nam,CONVERT(date,GETDATE()) FROM #Dong;
  INSERT dbo.ChiTietHoaDon(MaHoaDon,LoaiKhoan,MaVanPhong,MaDichVu,SoLuong,DonGiaApDung,TyLeNgay)
   SELECT h.MaHoaDon,d.LoaiKhoan,d.MaVanPhong,d.MaDichVu,d.SoLuong,d.DonGiaApDung,d.TyLeNgay
   FROM #Dong d JOIN @HD h ON h.MaCongTy=d.MaCongTy;
  COMMIT;
  SELECT h.MaHoaDon,h.MaCongTy,SUM(CONVERT(decimal(18,2),ROUND(d.SoLuong*d.DonGiaApDung*d.TyLeNgay,2))) AS TongTien
   FROM @HD h JOIN #Dong d ON d.MaCongTy=h.MaCongTy GROUP BY h.MaHoaDon,h.MaCongTy;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.USP_Trx_ThanhToanHoaDonVaVaoSoQuy
 @MaHoaDon int,
 @SoTien decimal(18,2),
 @NgayThanhToan date,
 @NguoiThu nvarchar(100) = NULL,
 @MaYeuCau uniqueidentifier = NULL
AS
BEGIN
 -- TV6 sửa: tên procedure được giữ để tương thích; chỉ ghi thanh toán đủ một lần trên HoaDonThang, không tạo sổ quỹ/phiếu thu độc lập.
 -- @MaYeuCau là tham số tương thích không lưu bền vững; không cam kết tính idempotent theo mã yêu cầu.
 SET NOCOUNT ON;
 SET ANSI_PADDING ON;
 SET ANSI_WARNINGS ON;
 SET ARITHABORT ON;
 SET CONCAT_NULL_YIELDS_NULL ON;
 SET NUMERIC_ROUNDABORT OFF;
 IF @@TRANCOUNT<>0 THROW 51000,N'Hay goi thu tuc ngoai transaction cua ung dung.',1;
 SET XACT_ABORT ON;
 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Khoa int;
  EXEC @Khoa=sys.sp_getapplock @Resource=N'TV4_NghiepVu',
    @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @Khoa<0 THROW 51001,N'Khong lay duoc khoa nghiep vu. Thu lai sau.',1;

  IF @MaHoaDon IS NULL OR @SoTien IS NULL OR @SoTien<=0 OR @NgayThanhToan IS NULL
   THROW 51401,N'Ma hoa don, so tien va ngay thanh toan phai hop le va khac NULL.',1;

  IF @NguoiThu IS NOT NULL AND LEN(LTRIM(RTRIM(@NguoiThu)))=0
   THROW 51404,N'Ten nguoi thu khong duoc la chuoi rong hoac toan dau cach.',1;
  SET @NguoiThu = CASE WHEN @NguoiThu IS NULL THEN NULL ELSE LTRIM(RTRIM(@NguoiThu)) END;

  DECLARE @TrangThai varchar(20), @NgayLap date, @TongTienHoaDon decimal(18,2);
  SELECT @TrangThai=h.TrangThai, @NgayLap=h.NgayLap
  FROM dbo.HoaDonThang h WITH(UPDLOCK,HOLDLOCK)
  WHERE h.MaHoaDon=@MaHoaDon;

  IF @TrangThai IS NULL
   THROW 51402,N'Hoa don khong ton tai.',1;
  IF @TrangThai='DA_THANH_TOAN'
   THROW 51403,N'Hoa don da duoc thanh toan truoc do.',1;
  IF @NgayThanhToan<@NgayLap OR @NgayThanhToan>CONVERT(date,GETDATE())
   THROW 51405,N'Ngay thanh toan phai tu NgayLap den hien tai.',1;

  SELECT @TongTienHoaDon = SUM(c.SoTien)
  FROM dbo.V_ChiTietHoaDon c
  WHERE c.MaHoaDon=@MaHoaDon;

  IF @TongTienHoaDon IS NULL OR @TongTienHoaDon<=0 OR @SoTien<>@TongTienHoaDon
   THROW 51406,N'So tien thanh toan khong khop tong tien hoa don (chi ho tro tra du 1 lan).',1;

  UPDATE dbo.HoaDonThang
  SET TrangThai='DA_THANH_TOAN',
      NgayThanhToan=@NgayThanhToan,
      NguoiThu=@NguoiThu
  WHERE MaHoaDon=@MaHoaDon AND TrangThai='CHUA_THANH_TOAN';

  IF @@ROWCOUNT<>1
   THROW 51407,N'Khong cap nhat duoc trang thai thanh toan.',1;

  COMMIT;
  SELECT h.MaHoaDon, h.MaCongTy, h.MaToaNha, h.Thang, h.Nam,
         h.TrangThai, h.NgayThanhToan, h.NguoiThu,
         @TongTienHoaDon AS SoTienDaThu, @MaYeuCau AS MaYeuCau
  FROM dbo.HoaDonThang h
  WHERE h.MaHoaDon=@MaHoaDon;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.USP_Trx_ChotBangLuongNhanVien
 @MaToaNha varchar(20),@Thang tinyint,@Nam smallint
AS
BEGIN
 SET NOCOUNT ON;
 SET ANSI_PADDING ON;
 SET ANSI_WARNINGS ON;
 SET ARITHABORT ON;
 SET CONCAT_NULL_YIELDS_NULL ON;
 SET NUMERIC_ROUNDABORT OFF;
 IF @@TRANCOUNT<>0 THROW 51000,N'Hay goi thu tuc ngoai transaction cua ung dung.',1;
 SET XACT_ABORT ON;
 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Khoa int;
  EXEC @Khoa=sys.sp_getapplock @Resource=N'TV4_NghiepVu',
    @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @Khoa<0 THROW 51001,N'Khong lay duoc khoa nghiep vu. Thu lai sau.',1;
  IF @Thang IS NULL OR @Thang NOT BETWEEN 1 AND 12 OR @Nam IS NULL OR @Nam NOT BETWEEN 1900 AND 9999
   THROW 51501,N'Thang hoac nam khong hop le.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.HoaDonThang WITH(UPDLOCK,HOLDLOCK)
    WHERE MaToaNha=@MaToaNha AND Thang=@Thang AND Nam=@Nam)
   THROW 51502,N'Phai chot hoa don cua toa nha truoc khi tinh luong.',1;
  DECLARE @TuKy date=DATEFROMPARTS(@Nam,@Thang,1),@DenKy date=EOMONTH(DATEFROMPARTS(@Nam,@Thang,1));
  ;WITH CongTyCanHoaDon AS(
   SELECT h.MaCongTy FROM dbo.HopDongThue h JOIN dbo.VanPhong v ON v.MaVanPhong=h.MaVanPhong
    WHERE v.MaToaNha=@MaToaNha AND h.NgayBatDau<=@DenKy AND ISNULL(h.NgayKetThuc,CONVERT(date,'99991231'))>=@TuKy
   UNION
   SELECT s.MaCongTy FROM dbo.SuDungDichVu s JOIN dbo.DichVu d ON d.MaDichVu=s.MaDichVu
    WHERE d.MaToaNha=@MaToaNha AND s.NgayBatDau<=@DenKy AND ISNULL(s.NgayKetThuc,CONVERT(date,'99991231'))>=@TuKy
  )
  SELECT MaCongTy INTO #ThieuHoaDon FROM CongTyCanHoaDon c WHERE NOT EXISTS(
   SELECT 1 FROM dbo.HoaDonThang h WHERE h.MaCongTy=c.MaCongTy AND h.MaToaNha=@MaToaNha AND h.Thang=@Thang AND h.Nam=@Nam);
  IF EXISTS(SELECT 1 FROM #ThieuHoaDon) THROW 51509,N'Con cong ty chua duoc lap hoa don trong ky.',1;
  IF EXISTS(SELECT 1 FROM dbo.LuongThang l JOIN dbo.NhanVienToaNha n ON n.MaNVTN=l.MaNVTN
      WHERE n.MaToaNha=@MaToaNha AND l.Thang=@Thang AND l.Nam=@Nam)
   THROW 51503,N'Ky da co luong. Khong tinh lai hoac ghi de.',1;
  DECLARE @Cuoi date=EOMONTH(DATEFROMPARTS(@Nam,@Thang,1));
  IF EXISTS(SELECT 1 FROM dbo.NhanVienToaNha n WHERE n.MaToaNha=@MaToaNha AND n.NgayVaoLam<=@Cuoi
    AND NOT EXISTS(SELECT 1 FROM dbo.PhanCongNVTN p
      WHERE p.MaNVTN=n.MaNVTN AND p.Thang=@Thang AND p.Nam=@Nam))
   THROW 51505,N'Co nhan vien chua duoc phan cong trong thang.',1;
  IF EXISTS(SELECT 1 FROM dbo.PhanCongNVTN p JOIN dbo.NhanVienToaNha n ON n.MaNVTN=p.MaNVTN
    LEFT JOIN dbo.DichVu d ON d.MaDichVu=p.MaDichVu
    LEFT JOIN dbo.BacCongViec b ON b.MaBac=p.MaBac
    WHERE n.MaToaNha=@MaToaNha AND p.Thang=@Thang AND p.Nam=@Nam
    AND (n.NgayVaoLam>@Cuoi OR b.MaBac IS NULL OR b.HeSoDoanhThu NOT BETWEEN 0 AND 1 OR b.LuongCoBan<=0
      OR (n.LoaiNV='QUAN_LY' AND p.MaDichVu IS NOT NULL)
      OR (n.LoaiNV='DICH_VU' AND (d.MaDichVu IS NULL OR d.MaToaNha<>@MaToaNha))
      OR n.LoaiNV NOT IN ('QUAN_LY','DICH_VU')))
   THROW 51506,N'Phan cong, bac luong hoac dich vu khong hop le.',1;
  IF (SELECT COUNT(*) FROM dbo.NhanVienToaNha WHERE MaToaNha=@MaToaNha
      AND LoaiNV='QUAN_LY' AND NgayVaoLam<=@Cuoi)<>1
   THROW 51507,N'Toa nha phai co dung mot quan ly trong thang.',1;
  /* TV3: HeSoDoanhThu la TY LE RIENG tung nhan vien, khong phai trong so.
     Quan ly khong gan MaDichVu nen doanh thu 0, thuong 0 nhu seed.
     Dich vu THANG va LUOT deu lay doanh thu tu chi tiet hoa don da chot. */
  SELECT n.MaNVTN,b.LuongCoBan,b.HeSoDoanhThu,
    CONVERT(decimal(18,2),ROUND(CAST(COALESCE(dt.DoanhThu,0) AS decimal(28,2))*b.HeSoDoanhThu,2)) AS TienThuong
  INTO #NhanVien
  FROM dbo.PhanCongNVTN p JOIN dbo.NhanVienToaNha n ON n.MaNVTN=p.MaNVTN
   JOIN dbo.BacCongViec b ON b.MaBac=p.MaBac
   OUTER APPLY(SELECT SUM(c.SoTien) AS DoanhThu
    FROM dbo.HoaDonThang h JOIN dbo.V_ChiTietHoaDon c ON c.MaHoaDon=h.MaHoaDon
    WHERE h.MaToaNha=@MaToaNha AND h.Thang=@Thang AND h.Nam=@Nam
      AND c.MaDichVu=p.MaDichVu AND c.LoaiKhoan IN ('DICH_VU_THANG','DICH_VU_LUOT')) dt
   WHERE n.MaToaNha=@MaToaNha AND p.Thang=@Thang AND p.Nam=@Nam;
  IF NOT EXISTS(SELECT 1 FROM #NhanVien) THROW 51508,N'Khong co nhan vien de tinh luong.',1;
  INSERT dbo.LuongThang(MaNVTN,Thang,Nam,LuongCoBan,TienThuong)
   SELECT MaNVTN,@Thang,@Nam,LuongCoBan,TienThuong FROM #NhanVien;
  COMMIT;
  SELECT l.MaNVTN,l.Thang,l.Nam,l.LuongCoBan,l.TienThuong,l.LuongCoBan+l.TienThuong AS TongLuong
   FROM dbo.LuongThang l JOIN #NhanVien n ON n.MaNVTN=l.MaNVTN WHERE l.Thang=@Thang AND l.Nam=@Nam;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO
