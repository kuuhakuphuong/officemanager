/*=============================================================================
  PHAN 5 — TRIGGER (TV5: Khuc Tuan Anh — CHHT001)
  Co so du lieu: QLToaNha_BCNF (18 bang + 1 view)
  DBMS         : SQL Server 2025 Express (T-SQL)
  Phoi hop     : TV3 (DDL 01_CreateSchema), TV4 (03_Transactions)
  Ma loi       : 55xxx (tranh trung TV4 dung 51xxx)
  ============================================================================= */
SET NOCOUNT ON;
GO

/* ============================================================================
   0.  BO SUNG COT TRANG THAI CHO VANPHONG (phuc vu trigger 5.5)
       Khong them bang moi — chi ALTER TABLE nen 18 bang khong doi.
   ============================================================================ */
IF COL_LENGTH('dbo.VanPhong','TrangThai') IS NULL
BEGIN
    ALTER TABLE dbo.VanPhong
        ADD TrangThai varchar(20) NOT NULL
        CONSTRAINT DF_VanPhong_TrangThai DEFAULT ('TRONG');
    PRINT N'[TV5] Da bo sung cot VanPhong.TrangThai.';
END;
GO

/* Them CHECK CONSTRAINT cho cot TrangThai (chi nhan TRONG hoac DANG_THUE) */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VanPhong_TrangThai')
BEGIN
    ALTER TABLE dbo.VanPhong ADD CONSTRAINT CK_VanPhong_TrangThai
        CHECK (TrangThai IN (N'TRONG', N'DANG_THUE'));
    PRINT N'[TV5] Da them CHECK CONSTRAINT CK_VanPhong_TrangThai.';
END;
GO

/* TV6 sửa: đây là trạng thái tại thời điểm chạy/có DML; web truy vấn hợp đồng để hiển thị trạng thái hôm nay khi ngày tự đổi. */
/* Cap nhat trang thai hien tai dua tren hop dong thue dang hoat dong */
UPDATE vp SET TrangThai = 'DANG_THUE'
FROM dbo.VanPhong vp
WHERE vp.TrangThai <> 'DANG_THUE'
  AND EXISTS (
    SELECT 1 FROM dbo.HopDongThue h
    WHERE h.MaVanPhong = vp.MaVanPhong
      AND h.NgayBatDau <= CONVERT(date, GETDATE())
      AND ISNULL(h.NgayKetThuc, CONVERT(date,'99991231')) >= CONVERT(date, GETDATE())
);
IF @@ROWCOUNT > 0 PRINT N'[TV5] Da cap nhat trang thai van phong hien tai.';
GO

/* ============================================================================
   5.1  TR_ChiTietThue_ChanTrungLap
        Bang  : HopDongThue
        Su kien: AFTER INSERT, UPDATE
        Muc dich: Ngan trung lich thue van phong cung thoi ky.
                  Lop bao ve thu 2 (TV4 T1 da kiem tra trong procedure).
   ============================================================================ */
CREATE OR ALTER TRIGGER dbo.TR_ChiTietThue_ChanTrungLap
ON dbo.HopDongThue
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* Chi kiem tra khi co dong anh huong */
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    /* Tim cac cap hop dong trung lich tren cung van phong */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.HopDongThue h ON h.MaVanPhong = i.MaVanPhong
                               AND h.MaHopDong <> i.MaHopDong
        WHERE i.NgayBatDau <= ISNULL(h.NgayKetThuc, CONVERT(date,'99991231'))
          AND h.NgayBatDau <= ISNULL(i.NgayKetThuc, CONVERT(date,'99991231'))
    )
    BEGIN
        ;THROW 55101, N'[TV5-5.1] Trung lich thue van phong. Moi van phong chi duoc cho thue boi mot cong ty trong cung thoi ky.', 1;
    END;
END;
GO

PRINT N'[TV5] Trigger 5.1 TR_ChiTietThue_ChanTrungLap — OK';
GO


/* ============================================================================
   5.2  TR_DangKyDichVu_ApDungBacThang
        Bang  : SuDungDichVu  (ten BCNF cua DangKyDichVu prototype)
        Su kien: AFTER INSERT
        Muc dich: Khi dang ky dich vu hang thang —
                  (a) Kiem tra cong ty co hop dong thue tai cung toa nha
                  (b) Tinh va hien thi bac gia luy tien hien tai
        Cong thuc: DonGiaCoBan * (1 + TY_LE_TANG_GIA * (bac_nguoi + bac_dien_tich))
                   — theo TV4 T3: CONG DON hai bac, khong lay MAX.
   ============================================================================ */
CREATE OR ALTER TRIGGER dbo.TR_DangKyDichVu_ApDungBacThang
ON dbo.SuDungDichVu
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    /* --- (a) Validate: chi dich vu THANG moi can kiem tra bac gia --- */
    /* Kiem tra: cong ty phai co hop dong thue hoat dong tai cung toa nha
       trong ky dang ky dich vu (i.NgayBatDau..i.NgayKetThuc),
       KHONG dung GETDATE() de tuong thich voi du lieu lich su va ky tuong lai */

    /* Kiem tra: cong ty phai co hop dong thue giao thoa voi ky dang ky DV */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.DichVu d ON d.MaDichVu = i.MaDichVu
        JOIN dbo.LoaiDichVu l ON l.MaLoaiDV = d.MaLoaiDV
        WHERE l.KieuTinhPhi = 'THANG'
          AND NOT EXISTS (
              SELECT 1 FROM dbo.HopDongThue h
              JOIN dbo.VanPhong v ON v.MaVanPhong = h.MaVanPhong
              WHERE h.MaCongTy = i.MaCongTy
                AND v.MaToaNha = d.MaToaNha
                AND h.NgayBatDau <= ISNULL(i.NgayKetThuc, CONVERT(date,'99991231'))
                AND ISNULL(h.NgayKetThuc, CONVERT(date,'99991231')) >= i.NgayBatDau
          )
    )
    BEGIN
        ;THROW 55201, N'[TV5-5.2] Cong ty chua co hop dong thue hoat dong tai toa nha cung cap dich vu. Khong the dang ky dich vu hang thang.', 1;
    END;

    /* --- (b) Tinh bac gia luy tien va thong bao --- */
    DECLARE @NguongNguoi  decimal(18,6), @BuocNguoi  decimal(18,6),
            @NguongDT     decimal(18,6), @BuocDT     decimal(18,6),
            @TyLe         decimal(18,6);

    SET ANSI_WARNINGS OFF;   -- tranh Warning: Null value is eliminated
    SELECT @NguongNguoi = MAX(CASE WHEN TenThamSo='NGUONG_NGUOI'      THEN GiaTri END),
           @BuocNguoi   = MAX(CASE WHEN TenThamSo='BUOC_NGUOI'        THEN GiaTri END),
           @NguongDT    = MAX(CASE WHEN TenThamSo='NGUONG_DIEN_TICH'  THEN GiaTri END),
           @BuocDT      = MAX(CASE WHEN TenThamSo='BUOC_DIEN_TICH'   THEN GiaTri END),
           @TyLe        = MAX(CASE WHEN TenThamSo='TY_LE_TANG_GIA'   THEN GiaTri END)
    FROM dbo.ThamSo
    WHERE TenThamSo IN ('NGUONG_NGUOI','BUOC_NGUOI',
                         'NGUONG_DIEN_TICH','BUOC_DIEN_TICH','TY_LE_TANG_GIA');
    SET ANSI_WARNINGS ON;

    /* Hien thi bac gia cho tung dong dang ky moi */
    DECLARE @Msg nvarchar(max) = N'';

    SELECT @Msg = @Msg
        + N'  DV=' + i.MaDichVu + N' | CT=' + i.MaCongTy
        + N' | SoNguoi=' + CAST(ng.SoNguoi AS varchar)
        + N' | DienTich=' + CAST(ISNULL(dt.DienTich,0) AS varchar)
        + N' | BacNguoi=' + CAST(
            CASE WHEN l.CoTinhTheoNguoi=1 AND ng.SoNguoi > @NguongNguoi
                 THEN CEILING((ng.SoNguoi - @NguongNguoi) / @BuocNguoi)
                 ELSE 0 END AS varchar)
        + N' | BacDT=' + CAST(
            CASE WHEN l.CoTinhTheoDienTich=1 AND ISNULL(dt.DienTich,0) > @NguongDT
                 THEN CEILING((ISNULL(dt.DienTich,0) - @NguongDT) / @BuocDT)
                 ELSE 0 END AS varchar)
        + N' | DonGiaApDung=' + CAST(
            CAST(ROUND(d.DonGiaCoBan * (1 + @TyLe * (
                CASE WHEN l.CoTinhTheoNguoi=1 AND ng.SoNguoi > @NguongNguoi
                     THEN CEILING((ng.SoNguoi - @NguongNguoi) / @BuocNguoi)
                     ELSE 0 END
              + CASE WHEN l.CoTinhTheoDienTich=1 AND ISNULL(dt.DienTich,0) > @NguongDT
                     THEN CEILING((ISNULL(dt.DienTich,0) - @NguongDT) / @BuocDT)
                     ELSE 0 END
            )), 2) AS decimal(18,2)) AS varchar)
        + CHAR(13) + CHAR(10)
    FROM inserted i
    JOIN dbo.DichVu d ON d.MaDichVu = i.MaDichVu
    JOIN dbo.LoaiDichVu l ON l.MaLoaiDV = d.MaLoaiDV
    CROSS APPLY (
        SELECT COUNT(*) AS SoNguoi
        FROM dbo.NhanVienCongTy nv
        WHERE nv.MaCongTy = i.MaCongTy
          AND nv.NgayVaoLam <= i.NgayBatDau
          AND ISNULL(nv.NgayNghiViec, CONVERT(date,'99991231')) >= i.NgayBatDau
    ) ng
    OUTER APPLY (
        SELECT CAST(SUM(v.DienTich) AS decimal(18,2)) AS DienTich
        FROM dbo.HopDongThue h
        JOIN dbo.VanPhong v ON v.MaVanPhong = h.MaVanPhong
        WHERE h.MaCongTy = i.MaCongTy
          AND v.MaToaNha = d.MaToaNha
          AND h.NgayBatDau <= i.NgayBatDau
          AND ISNULL(h.NgayKetThuc, CONVERT(date,'99991231')) >= i.NgayBatDau
    ) dt
    WHERE l.KieuTinhPhi = 'THANG';

    IF @Msg <> N''
        PRINT N'[TV5-5.2] Bac gia luy tien hien tai (SUM bac nguoi + bac DT):' + CHAR(13) + CHAR(10) + @Msg;
END;
GO

PRINT N'[TV5] Trigger 5.2 TR_DangKyDichVu_ApDungBacThang — OK';
GO


/* ============================================================================
   5.3  TR_NhatKyDichVu_KiemTraHopLe
        Bang  : ChiTietSuDungNV
        Su kien: AFTER INSERT, UPDATE
        Muc dich: Xac thuc nhat ky su dung dich vu —
                  (a) Nhan vien thuoc cong ty co dang ky dich vu do (SuDungDichVu)
                  (b) Nhan vien con lam viec tai ngay su dung
                  (c) Ngay su dung <= ngay hien tai
                  (d) Dich vu phai la loai tinh phi theo LUOT
                  (e) Cong ty co hop dong thue tai toa nha cung cap DV (55305)
   ============================================================================ */
CREATE OR ALTER TRIGGER dbo.TR_NhatKyDichVu_KiemTraHopLe
ON dbo.ChiTietSuDungNV
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    /* (d) Dich vu phai la loai LUOT */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.DichVu d ON d.MaDichVu = i.MaDichVu
        JOIN dbo.LoaiDichVu l ON l.MaLoaiDV = d.MaLoaiDV
        WHERE l.KieuTinhPhi <> 'LUOT'
    )
    BEGIN
        ;THROW 55304, N'[TV5-5.3] Chi tinh phi theo luot (LUOT) moi duoc ghi nhat ky su dung. Dich vu hang thang (THANG) khong ghi nhat ky.', 1;
    END;

    /* (c) Ngay su dung khong duoc vuot qua ngay hien tai */
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE NgaySuDung > CONVERT(date, GETDATE())
    )
    BEGIN
        ;THROW 55303, N'[TV5-5.3] Ngay su dung khong duoc lon hon ngay hien tai.', 1;
    END;

    /* (b) Nhan vien con lam viec tai thoi diem su dung */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.NhanVienCongTy nv ON nv.MaNVCT = i.MaNVCT
        WHERE i.NgaySuDung < nv.NgayVaoLam
           OR (nv.NgayNghiViec IS NOT NULL AND i.NgaySuDung > nv.NgayNghiViec)
    )
    BEGIN
        ;THROW 55302, N'[TV5-5.3] Nhan vien khong con lam viec tai thoi diem su dung dich vu.', 1;
    END;

    /* (a) Cong ty cua nhan vien phai dang ky su dung dich vu do (SuDungDichVu) */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.NhanVienCongTy nv ON nv.MaNVCT = i.MaNVCT
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.SuDungDichVu s
            WHERE s.MaCongTy = nv.MaCongTy
              AND s.MaDichVu = i.MaDichVu
              AND s.NgayBatDau <= i.NgaySuDung
              AND ISNULL(s.NgayKetThuc, CONVERT(date,'99991231')) >= i.NgaySuDung
        )
    )
    BEGIN
        ;THROW 55301, N'[TV5-5.3] Cong ty cua nhan vien chua dang ky su dung dich vu nay tai thoi diem ghi nhat ky.', 1;
    END;

    /* (e) Cong ty phai co hop dong thue van phong hieu luc tai toa nha cung cap DV vao NgaySuDung */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.NhanVienCongTy nv ON nv.MaNVCT = i.MaNVCT
        JOIN dbo.DichVu d ON d.MaDichVu = i.MaDichVu
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.HopDongThue h
            JOIN dbo.VanPhong v ON v.MaVanPhong = h.MaVanPhong
            WHERE h.MaCongTy = nv.MaCongTy
              AND v.MaToaNha = d.MaToaNha
              AND h.NgayBatDau <= i.NgaySuDung
              AND (h.NgayKetThuc IS NULL OR h.NgayKetThuc >= i.NgaySuDung)
        )
    )
    BEGIN
        ;THROW 55305, N'[TV5-5.3] Cong ty khong co hop dong thue van phong hieu luc tai toa nha cung cap dich vu vao NgaySuDung.', 1;
    END;
END;
GO

PRINT N'[TV5] Trigger 5.3 TR_NhatKyDichVu_KiemTraHopLe — OK';
GO


/* ============================================================================
   5.4  TR_CongTy_ChanXoa  +  TR_ToaNha_ChanXoa
        Bang  : CongTy, ToaNha
        Su kien: INSTEAD OF DELETE
        Muc dich: Khoa an toan — khong cho xoa CongTy/ToaNha khi con du lieu phu thuoc.
                  Kiem tra tat ca FK phu thuoc truoc khi cho xoa.
   ============================================================================ */

/* --- 5.4a  CongTy --- */
CREATE OR ALTER TRIGGER dbo.TR_CongTy_ChanXoa
ON dbo.CongTy
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    /* Kiem tra toan bo FK tham chieu den CongTy */
    DECLARE @CongTyPhuThuoc nvarchar(max) = N'';

    SELECT @CongTyPhuThuoc = @CongTyPhuThuoc + d.MaCongTy + N', '
    FROM deleted d
    WHERE EXISTS (SELECT 1 FROM dbo.HopDongThue h WHERE h.MaCongTy = d.MaCongTy)
       OR EXISTS (SELECT 1 FROM dbo.NhanVienCongTy nv WHERE nv.MaCongTy = d.MaCongTy)
       OR EXISTS (SELECT 1 FROM dbo.SuDungDichVu s WHERE s.MaCongTy = d.MaCongTy)
       OR EXISTS (SELECT 1 FROM dbo.HoaDonThang hd WHERE hd.MaCongTy = d.MaCongTy);

    IF @CongTyPhuThuoc <> N''
    BEGIN
        SET @CongTyPhuThuoc = LEFT(@CongTyPhuThuoc, LEN(@CongTyPhuThuoc) - 1);
        DECLARE @Msg54a nvarchar(400) = N'[TV5-5.4] Khong the xoa CongTy (' + @CongTyPhuThuoc + N'): con du lieu phu thuoc (HopDongThue, NhanVienCongTy, SuDungDichVu, HoaDonThang).';
        ;THROW 55401, @Msg54a, 1;
    END;

    /* Khong co phu thuoc — cho phep xoa */
    DELETE ct
    FROM dbo.CongTy ct
    JOIN deleted d ON ct.MaCongTy = d.MaCongTy;

    PRINT N'[TV5-5.4] Da xoa cong ty khong con phu thuoc.';
END;
GO

/* --- 5.4b  ToaNha --- */
CREATE OR ALTER TRIGGER dbo.TR_ToaNha_ChanXoa
ON dbo.ToaNha
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    DECLARE @ToaNhaPhuThuoc nvarchar(max) = N'';

    SELECT @ToaNhaPhuThuoc = @ToaNhaPhuThuoc + d.MaToaNha + N', '
    FROM deleted d
    WHERE EXISTS (SELECT 1 FROM dbo.VanPhong v WHERE v.MaToaNha = d.MaToaNha)
       OR EXISTS (SELECT 1 FROM dbo.DichVu dv WHERE dv.MaToaNha = d.MaToaNha)
       OR EXISTS (SELECT 1 FROM dbo.NhanVienToaNha n WHERE n.MaToaNha = d.MaToaNha)
       OR EXISTS (SELECT 1 FROM dbo.HoaDonThang hd WHERE hd.MaToaNha = d.MaToaNha)
       OR EXISTS (SELECT 1 FROM dbo.ChiPhiVanHanh cp WHERE cp.MaToaNha = d.MaToaNha);

    IF @ToaNhaPhuThuoc <> N''
    BEGIN
        SET @ToaNhaPhuThuoc = LEFT(@ToaNhaPhuThuoc, LEN(@ToaNhaPhuThuoc) - 1);
        DECLARE @Msg54b nvarchar(400) = N'[TV5-5.4] Khong the xoa ToaNha (' + @ToaNhaPhuThuoc + N'): con du lieu phu thuoc (VanPhong, DichVu, NhanVienToaNha, HoaDonThang, ChiPhiVanHanh).';
        ;THROW 55402, @Msg54b, 1;
    END;

    DELETE tn
    FROM dbo.ToaNha tn
    JOIN deleted d ON tn.MaToaNha = d.MaToaNha;

    PRINT N'[TV5-5.4] Da xoa toa nha khong con phu thuoc.';
END;
GO

PRINT N'[TV5] Trigger 5.4 TR_CongTy_ChanXoa + TR_ToaNha_ChanXoa — OK';
GO


/* ============================================================================
   5.5  TR_ChiTietThue_DongBoDienTich
        Bang  : HopDongThue
        Su kien: AFTER INSERT, UPDATE, DELETE
        Muc dich: Tu dong dong bo —
                  (a) VanPhong.TrangThai = 'DANG_THUE' neu co hop dong hoat dong,
                      'TRONG' neu khong.
                  (b) In thong bao tong dien tich dang thue theo toa nha
                      (phuc vu dashboard / bao cao).
        Luu y  : Trigger 5.1 (chan trung lap) fire TRUOC trigger nay
                 vi cung la AFTER INSERT/UPDATE tren HopDongThue.
   ============================================================================ */
CREATE OR ALTER TRIGGER dbo.TR_ChiTietThue_DongBoDienTich
ON dbo.HopDongThue
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @HomNay date = CONVERT(date, GETDATE());

    /* Thu thap tat ca MaVanPhong bi anh huong (inserted + deleted) */
    DECLARE @VP TABLE (MaVanPhong varchar(20) PRIMARY KEY);

    INSERT @VP (MaVanPhong)
    SELECT MaVanPhong FROM inserted
    UNION
    SELECT MaVanPhong FROM deleted;

    IF NOT EXISTS (SELECT 1 FROM @VP) RETURN;

    /* (a) Cap nhat TrangThai cho cac van phong bi anh huong */
    UPDATE vp
    SET TrangThai = CASE
        WHEN EXISTS (
            SELECT 1 FROM dbo.HopDongThue h
            WHERE h.MaVanPhong = vp.MaVanPhong
              AND h.NgayBatDau <= @HomNay
              AND ISNULL(h.NgayKetThuc, CONVERT(date,'99991231')) >= @HomNay
        ) THEN 'DANG_THUE'
        ELSE 'TRONG'
    END
    FROM dbo.VanPhong vp
    JOIN @VP a ON a.MaVanPhong = vp.MaVanPhong;

    /* (b) Thong bao tong dien tich dang thue theo toa nha */
    DECLARE @Msg nvarchar(max) = N'';

    SELECT @Msg = @Msg
        + N'  ToaNha=' + tn.MaToaNha
        + N' | TongDienTichThue=' + CAST(ISNULL(SUM(
            CASE WHEN h.MaHopDong IS NOT NULL THEN v.DienTich ELSE 0 END
          ), 0) AS varchar)
        + N' m2 | SoVP_DangThue=' + CAST(SUM(
            CASE WHEN h.MaHopDong IS NOT NULL THEN 1 ELSE 0 END
          ) AS varchar)
        + N'/' + CAST(COUNT(*) AS varchar)
        + CHAR(13) + CHAR(10)
    FROM dbo.VanPhong v
    JOIN dbo.ToaNha tn ON tn.MaToaNha = v.MaToaNha
    LEFT JOIN dbo.HopDongThue h ON h.MaVanPhong = v.MaVanPhong
        AND h.NgayBatDau <= @HomNay
        AND ISNULL(h.NgayKetThuc, CONVERT(date,'99991231')) >= @HomNay
    WHERE v.MaToaNha IN (
        SELECT DISTINCT v2.MaToaNha
        FROM @VP a2 JOIN dbo.VanPhong v2 ON v2.MaVanPhong = a2.MaVanPhong
    )
    GROUP BY tn.MaToaNha;

    IF @Msg <> N''
        PRINT N'[TV5-5.5] Dong bo trang thai van phong. Thong ke toa nha:' + CHAR(13) + CHAR(10) + @Msg;
END;
GO

PRINT N'[TV5] Trigger 5.5 TR_ChiTietThue_DongBoDienTich — OK';
GO


/* ============================================================================
   TONG HOP: Kiem tra tat ca 6 trigger da duoc tao thanh cong
   ============================================================================ */
DECLARE @cnt int;
SELECT @cnt = COUNT(*)
FROM sys.triggers
WHERE name IN (
    'TR_ChiTietThue_ChanTrungLap',
    'TR_DangKyDichVu_ApDungBacThang',
    'TR_NhatKyDichVu_KiemTraHopLe',
    'TR_CongTy_ChanXoa',
    'TR_ToaNha_ChanXoa',
    'TR_ChiTietThue_DongBoDienTich'
);
IF @cnt <> 6
    THROW 55000, N'[TV5] THAT BAI — khong du 6 trigger. Kiem tra log.', 1;

SELECT N'[TV5] HOAN THANH — 6/6 trigger da tao thanh cong.' AS KetQua;
GO
