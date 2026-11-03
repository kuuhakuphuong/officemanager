/* TV6 sửa: migration không xóa dữ liệu cho schema TV3 đã tồn tại.
   Sao lưu CSDL trước khi chạy. Chỉ chạy trên QLToaNha_BCNF sau khi xác nhận đúng phiên bản 18 bảng. */
USE QLToaNha_BCNF;
GO
SET XACT_ABORT ON;
IF (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0 AND name <> 'sysdiagrams') <> 18
    THROW 51620, N'Can dung schema TV3 gom 18 bang nghiep vu.', 1;
IF EXISTS (SELECT 1 FROM dbo.DichVu WHERE DonGiaCoBan <= 0)
    THROW 51621, N'Con dich vu co don gia khong duong; can xu ly du lieu truoc khi doi CHECK.', 1;
GO
BEGIN TRY
    BEGIN TRANSACTION;

    -- TV6 sửa: ba khoảng ngày đều cho phép ngày đầu bằng ngày cuối.
    IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.HopDongThue') AND name = N'CK_HopDongThue_Ngay')
        ALTER TABLE dbo.HopDongThue DROP CONSTRAINT CK_HopDongThue_Ngay;
    ALTER TABLE dbo.HopDongThue WITH CHECK ADD CONSTRAINT CK_HopDongThue_Ngay
        CHECK (NgayKetThuc IS NULL OR NgayKetThuc >= NgayBatDau);

    IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.SuDungDichVu') AND name = N'CK_SuDungDichVu_Ngay')
        ALTER TABLE dbo.SuDungDichVu DROP CONSTRAINT CK_SuDungDichVu_Ngay;
    ALTER TABLE dbo.SuDungDichVu WITH CHECK ADD CONSTRAINT CK_SuDungDichVu_Ngay
        CHECK (NgayKetThuc IS NULL OR NgayKetThuc >= NgayBatDau);

    IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.NhanVienCongTy') AND name = N'CK_NhanVienCongTy_NgayNghi')
        ALTER TABLE dbo.NhanVienCongTy DROP CONSTRAINT CK_NhanVienCongTy_NgayNghi;
    ALTER TABLE dbo.NhanVienCongTy WITH CHECK ADD CONSTRAINT CK_NhanVienCongTy_NgayNghi
        CHECK (NgayNghiViec IS NULL OR NgayNghiViec >= NgayVaoLam);

    -- TV6 sửa: đơn giá cơ bản dịch vụ phải lớn hơn 0 giống API.
    IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.DichVu') AND name = N'CK_DichVu_DonGia')
        ALTER TABLE dbo.DichVu DROP CONSTRAINT CK_DichVu_DonGia;
    ALTER TABLE dbo.DichVu WITH CHECK ADD CONSTRAINT CK_DichVu_DonGia CHECK (DonGiaCoBan > 0);

    COMMIT TRANSACTION;
    PRINT N'TV6 sua: da dong bo quy tac ngay va don gia tren 18 bang.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
