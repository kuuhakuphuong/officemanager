/* Chi tao 2 table-valued parameter types, khong them bang nghiep vu.
   Neu type cung ten da ton tai, doi chieu cau truc truoc khi tai su dung. */
IF TYPE_ID(N'dbo.TT_DanhSachPhong') IS NULL
 EXEC(N'CREATE TYPE dbo.TT_DanhSachPhong AS TABLE(MaVanPhong varchar(20) NOT NULL PRIMARY KEY)');
GO
IF TYPE_ID(N'dbo.TT_DanhSachSuDung') IS NULL
 EXEC(N'CREATE TYPE dbo.TT_DanhSachSuDung AS TABLE(
 MaNVCT varchar(20) NOT NULL,MaDichVu varchar(20) NOT NULL,NgaySuDung date NOT NULL,SoLuot int NOT NULL,
 PRIMARY KEY(MaNVCT,MaDichVu,NgaySuDung))');
GO
