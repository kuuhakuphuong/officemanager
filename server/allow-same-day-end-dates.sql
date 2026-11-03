-- TV6 sửa: script cũ chỉ đổi hai CHECK; dùng Phần của thành viên 3/BCNF_BanGiao/06_ThongNhatQuyTac.sql cho quy ước đầy đủ bốn CHECK.
USE QLToaNha_BCNF;
GO
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'dbo.HopDongThue', N'U') IS NULL
        OR OBJECT_ID(N'dbo.NhanVienCongTy', N'U') IS NULL
        THROW 51000, N'Chưa có lược đồ BCNF của TV3.', 1;

    IF EXISTS (SELECT 1 FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.HopDongThue') AND name = N'CK_HopDongThue_Ngay')
        ALTER TABLE dbo.HopDongThue DROP CONSTRAINT CK_HopDongThue_Ngay;
    ALTER TABLE dbo.HopDongThue WITH CHECK ADD CONSTRAINT CK_HopDongThue_Ngay
        CHECK (NgayKetThuc IS NULL OR NgayKetThuc >= NgayBatDau);

    IF EXISTS (SELECT 1 FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.NhanVienCongTy') AND name = N'CK_NhanVienCongTy_NgayNghi')
        ALTER TABLE dbo.NhanVienCongTy DROP CONSTRAINT CK_NhanVienCongTy_NgayNghi;
    ALTER TABLE dbo.NhanVienCongTy WITH CHECK ADD CONSTRAINT CK_NhanVienCongTy_NgayNghi
        CHECK (NgayNghiViec IS NULL OR NgayNghiViec >= NgayVaoLam);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
