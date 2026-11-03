/*=============================================================================
  PHAN 5 - TRIGGER (TV5: Khuc Tuan Anh - CHHT001) - ban MySQL 8.0
  Co so du lieu: QLToaNha_BCNF (18 bang + 1 view)
  Ma loi       : 55xxx (tranh trung TV4 dung 51xxx)
  Khac biet voi ban SQL Server:
    - MySQL khong co INSTEAD OF / inserted / deleted: 5.4 dung BEFORE DELETE,
      5.1 va 5.5 tach thanh trigger rieng cho INSERT / UPDATE / DELETE.
    - Logic kiem tra dung chung nam trong 3 stored procedure, trigger chi goi lai.
    - PRINT khong co trong trigger MySQL nen thong bao bac gia / thong ke bi bo.
  Thong bao loi (SIGNAL MESSAGE_TEXT) toi da 128 ky tu theo gioi han cua MySQL.
  ============================================================================= */
USE QLToaNha_BCNF;

/* ============================================================================
   0. BO SUNG COT TRANG THAI CHO VANPHONG (phuc vu trigger 5.5)
   Khong them bang moi - chi ALTER TABLE nen 18 bang khong doi.
   ============================================================================ */
SET @sqlTrangThai = IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'VanPhong' AND COLUMN_NAME = 'TrangThai') = 0,
    "ALTER TABLE VanPhong ADD COLUMN TrangThai VARCHAR(20) NOT NULL DEFAULT 'TRONG', ADD CONSTRAINT CK_VanPhong_TrangThai CHECK (TrangThai IN ('TRONG', 'DANG_THUE'))",
    'SELECT 1');
PREPARE stTrangThai FROM @sqlTrangThai;
EXECUTE stTrangThai;
DEALLOCATE PREPARE stTrangThai;

/* TV6 sua: day la trang thai tai thoi diem chay/co DML; web truy van hop dong de hien thi trang thai hom nay khi ngay tu doi. */
UPDATE VanPhong vp SET vp.TrangThai = 'DANG_THUE'
WHERE vp.TrangThai <> 'DANG_THUE'
  AND EXISTS (
    SELECT 1 FROM HopDongThue h
    WHERE h.MaVanPhong = vp.MaVanPhong
      AND h.NgayBatDau <= CURDATE()
      AND COALESCE(h.NgayKetThuc, DATE '9999-12-31') >= CURDATE()
  );

DELIMITER $$

/* ============================================================================
   Stored procedure dung chung (duoc goi tu trigger, khong tra result set)
   ============================================================================ */

/* 5.1: chong trung lich thue van phong */
DROP PROCEDURE IF EXISTS usp_TV5_KiemTraChongLich$$
CREATE PROCEDURE usp_TV5_KiemTraChongLich(
    IN p_MaHopDong VARCHAR(20), IN p_MaVanPhong VARCHAR(20),
    IN p_NgayBatDau DATE, IN p_NgayKetThuc DATE)
BEGIN
    IF EXISTS (
        SELECT 1 FROM HopDongThue h
        WHERE h.MaVanPhong = p_MaVanPhong
          AND h.MaHopDong <> p_MaHopDong
          AND p_NgayBatDau <= COALESCE(h.NgayKetThuc, DATE '9999-12-31')
          AND h.NgayBatDau <= COALESCE(p_NgayKetThuc, DATE '9999-12-31')
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[TV5-5.1] Trung lich thue van phong. Moi van phong chi duoc cho thue boi mot cong ty trong cung thoi ky.', MYSQL_ERRNO = 55101;
    END IF;
END$$

/* 5.3: xac thuc nhat ky su dung dich vu (thu tu kiem tra giong ban SQL Server) */
DROP PROCEDURE IF EXISTS usp_TV5_KiemTraNhatKy$$
CREATE PROCEDURE usp_TV5_KiemTraNhatKy(
    IN p_MaNVCT VARCHAR(20), IN p_MaDichVu VARCHAR(20), IN p_NgaySuDung DATE)
BEGIN
    /* (d) Dich vu phai la loai LUOT */
    IF EXISTS (
        SELECT 1 FROM DichVu d JOIN LoaiDichVu l ON l.MaLoaiDV = d.MaLoaiDV
        WHERE d.MaDichVu = p_MaDichVu AND l.KieuTinhPhi <> 'LUOT'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[TV5-5.3] Chi tinh phi theo luot (LUOT) moi duoc ghi nhat ky su dung.', MYSQL_ERRNO = 55304;
    END IF;

    /* (c) Ngay su dung khong duoc vuot qua ngay hien tai */
    IF p_NgaySuDung > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[TV5-5.3] Ngay su dung khong duoc lon hon ngay hien tai.', MYSQL_ERRNO = 55303;
    END IF;

    /* (b) Nhan vien con lam viec tai thoi diem su dung */
    IF EXISTS (
        SELECT 1 FROM NhanVienCongTy nv
        WHERE nv.MaNVCT = p_MaNVCT
          AND (p_NgaySuDung < nv.NgayVaoLam
               OR (nv.NgayNghiViec IS NOT NULL AND p_NgaySuDung > nv.NgayNghiViec))
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[TV5-5.3] Nhan vien khong con lam viec tai thoi diem su dung dich vu.', MYSQL_ERRNO = 55302;
    END IF;

    /* (a) Cong ty cua nhan vien phai dang ky su dung dich vu do (SuDungDichVu) */
    IF EXISTS (
        SELECT 1 FROM NhanVienCongTy nv
        WHERE nv.MaNVCT = p_MaNVCT
          AND NOT EXISTS (
            SELECT 1 FROM SuDungDichVu s
            WHERE s.MaCongTy = nv.MaCongTy
              AND s.MaDichVu = p_MaDichVu
              AND s.NgayBatDau <= p_NgaySuDung
              AND COALESCE(s.NgayKetThuc, DATE '9999-12-31') >= p_NgaySuDung)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[TV5-5.3] Cong ty cua nhan vien chua dang ky su dung dich vu nay tai thoi diem ghi nhat ky.', MYSQL_ERRNO = 55301;
    END IF;

    /* (e) Cong ty phai co hop dong thue van phong hieu luc tai toa nha cung cap DV vao NgaySuDung */
    IF EXISTS (
        SELECT 1 FROM NhanVienCongTy nv
        JOIN DichVu d ON d.MaDichVu = p_MaDichVu
        WHERE nv.MaNVCT = p_MaNVCT
          AND NOT EXISTS (
            SELECT 1 FROM HopDongThue h
            JOIN VanPhong v ON v.MaVanPhong = h.MaVanPhong
            WHERE h.MaCongTy = nv.MaCongTy
              AND v.MaToaNha = d.MaToaNha
              AND h.NgayBatDau <= p_NgaySuDung
              AND (h.NgayKetThuc IS NULL OR h.NgayKetThuc >= p_NgaySuDung))
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[TV5-5.3] Cong ty khong co hop dong thue van phong hieu luc tai toa nha cung cap dich vu vao NgaySuDung.', MYSQL_ERRNO = 55305;
    END IF;
END$$

/* 5.5: dong bo VanPhong.TrangThai theo hop dong dang hieu luc hom nay */
DROP PROCEDURE IF EXISTS usp_TV5_DongBoTrangThai$$
CREATE PROCEDURE usp_TV5_DongBoTrangThai(IN p_MaVanPhong VARCHAR(20))
BEGIN
    IF p_MaVanPhong IS NOT NULL THEN
        UPDATE VanPhong vp
        SET vp.TrangThai = CASE WHEN EXISTS (
                SELECT 1 FROM HopDongThue h
                WHERE h.MaVanPhong = vp.MaVanPhong
                  AND h.NgayBatDau <= CURDATE()
                  AND COALESCE(h.NgayKetThuc, DATE '9999-12-31') >= CURDATE()
            ) THEN 'DANG_THUE' ELSE 'TRONG' END
        WHERE vp.MaVanPhong = p_MaVanPhong;
    END IF;
END$$

/* ============================================================================
   5.1  TR_ChiTietThue_ChanTrungLap  (HopDongThue, AFTER INSERT / UPDATE)
   ============================================================================ */
DROP TRIGGER IF EXISTS TR_ChiTietThue_ChanTrungLap_Ins$$
CREATE TRIGGER TR_ChiTietThue_ChanTrungLap_Ins AFTER INSERT ON HopDongThue FOR EACH ROW
BEGIN
    CALL usp_TV5_KiemTraChongLich(NEW.MaHopDong, NEW.MaVanPhong, NEW.NgayBatDau, NEW.NgayKetThuc);
END$$

DROP TRIGGER IF EXISTS TR_ChiTietThue_ChanTrungLap_Upd$$
CREATE TRIGGER TR_ChiTietThue_ChanTrungLap_Upd AFTER UPDATE ON HopDongThue FOR EACH ROW
BEGIN
    CALL usp_TV5_KiemTraChongLich(NEW.MaHopDong, NEW.MaVanPhong, NEW.NgayBatDau, NEW.NgayKetThuc);
END$$

/* ============================================================================
   5.2  TR_DangKyDichVu_ApDungBacThang  (SuDungDichVu, BEFORE INSERT)
        Dich vu THANG phai co hop dong thue hieu luc giao thoa ky dang ky tai cung toa nha.
        Ghi chu: ban SQL Server in them bac gia luy tien (PRINT); MySQL khong co PRINT trong trigger nen bo phan thong bao nay.
   ============================================================================ */
DROP TRIGGER IF EXISTS TR_DangKyDichVu_ApDungBacThang$$
CREATE TRIGGER TR_DangKyDichVu_ApDungBacThang BEFORE INSERT ON SuDungDichVu FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM DichVu d
        JOIN LoaiDichVu l ON l.MaLoaiDV = d.MaLoaiDV
        WHERE d.MaDichVu = NEW.MaDichVu
          AND l.KieuTinhPhi = 'THANG'
          AND NOT EXISTS (
              SELECT 1 FROM HopDongThue h
              JOIN VanPhong v ON v.MaVanPhong = h.MaVanPhong
              WHERE h.MaCongTy = NEW.MaCongTy
                AND v.MaToaNha = d.MaToaNha
                AND h.NgayBatDau <= COALESCE(NEW.NgayKetThuc, DATE '9999-12-31')
                AND COALESCE(h.NgayKetThuc, DATE '9999-12-31') >= NEW.NgayBatDau
          )
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[TV5-5.2] Cong ty chua co hop dong thue tai toa nha cung cap dich vu. Khong the dang ky dich vu thang.', MYSQL_ERRNO = 55201;
    END IF;
END$$

/* ============================================================================
   5.3  TR_NhatKyDichVu_KiemTraHopLe  (ChiTietSuDungNV, BEFORE INSERT / UPDATE)
   ============================================================================ */
DROP TRIGGER IF EXISTS TR_NhatKyDichVu_KiemTraHopLe_Ins$$
CREATE TRIGGER TR_NhatKyDichVu_KiemTraHopLe_Ins BEFORE INSERT ON ChiTietSuDungNV FOR EACH ROW
BEGIN
    CALL usp_TV5_KiemTraNhatKy(NEW.MaNVCT, NEW.MaDichVu, NEW.NgaySuDung);
END$$

DROP TRIGGER IF EXISTS TR_NhatKyDichVu_KiemTraHopLe_Upd$$
CREATE TRIGGER TR_NhatKyDichVu_KiemTraHopLe_Upd BEFORE UPDATE ON ChiTietSuDungNV FOR EACH ROW
BEGIN
    CALL usp_TV5_KiemTraNhatKy(NEW.MaNVCT, NEW.MaDichVu, NEW.NgaySuDung);
END$$

/* ============================================================================
   5.4  TR_CongTy_ChanXoa / TR_ToaNha_ChanXoa  (BEFORE DELETE)
        Khoa an toan: khong cho xoa khi con du lieu phu thuoc.
   ============================================================================ */
DROP TRIGGER IF EXISTS TR_CongTy_ChanXoa$$
CREATE TRIGGER TR_CongTy_ChanXoa BEFORE DELETE ON CongTy FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM HopDongThue WHERE MaCongTy = OLD.MaCongTy)
        OR EXISTS (SELECT 1 FROM NhanVienCongTy WHERE MaCongTy = OLD.MaCongTy)
        OR EXISTS (SELECT 1 FROM SuDungDichVu WHERE MaCongTy = OLD.MaCongTy)
        OR EXISTS (SELECT 1 FROM HoaDonThang WHERE MaCongTy = OLD.MaCongTy) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[TV5-5.4] Khong the xoa CongTy: con du lieu phu thuoc (HopDongThue, NhanVienCongTy, SuDungDichVu, HoaDonThang).', MYSQL_ERRNO = 55401;
    END IF;
END$$

DROP TRIGGER IF EXISTS TR_ToaNha_ChanXoa$$
CREATE TRIGGER TR_ToaNha_ChanXoa BEFORE DELETE ON ToaNha FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM VanPhong WHERE MaToaNha = OLD.MaToaNha)
        OR EXISTS (SELECT 1 FROM DichVu WHERE MaToaNha = OLD.MaToaNha)
        OR EXISTS (SELECT 1 FROM NhanVienToaNha WHERE MaToaNha = OLD.MaToaNha)
        OR EXISTS (SELECT 1 FROM HoaDonThang WHERE MaToaNha = OLD.MaToaNha)
        OR EXISTS (SELECT 1 FROM ChiPhiVanHanh WHERE MaToaNha = OLD.MaToaNha) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[TV5-5.4] Khong the xoa ToaNha: con du lieu phu thuoc (VanPhong, DichVu, NhanVienToaNha, HoaDonThang, ChiPhiVanHanh).', MYSQL_ERRNO = 55402;
    END IF;
END$$

/* ============================================================================
   5.5  TR_ChiTietThue_DongBoDienTich  (HopDongThue, AFTER INSERT / UPDATE / DELETE)
        Dong bo VanPhong.TrangThai: DANG_THUE neu co hop dong hieu luc, TRONG neu khong.
        Luu y: trigger 5.1 chay truoc vi cung la AFTER INSERT/UPDATE tren HopDongThue.
   ============================================================================ */
DROP TRIGGER IF EXISTS TR_ChiTietThue_DongBoDienTich_Ins$$
CREATE TRIGGER TR_ChiTietThue_DongBoDienTich_Ins AFTER INSERT ON HopDongThue FOR EACH ROW
BEGIN
    CALL usp_TV5_DongBoTrangThai(NEW.MaVanPhong);
END$$

DROP TRIGGER IF EXISTS TR_ChiTietThue_DongBoDienTich_Upd$$
CREATE TRIGGER TR_ChiTietThue_DongBoDienTich_Upd AFTER UPDATE ON HopDongThue FOR EACH ROW
BEGIN
    CALL usp_TV5_DongBoTrangThai(OLD.MaVanPhong);
    CALL usp_TV5_DongBoTrangThai(NEW.MaVanPhong);
END$$

DROP TRIGGER IF EXISTS TR_ChiTietThue_DongBoDienTich_Del$$
CREATE TRIGGER TR_ChiTietThue_DongBoDienTich_Del AFTER DELETE ON HopDongThue FOR EACH ROW
BEGIN
    CALL usp_TV5_DongBoTrangThai(OLD.MaVanPhong);
END$$

DELIMITER ;

/* ============================================================================
   TONG HOP: kiem tra 10 trigger vat ly (6 quy tac, 3 trigger cho 5.1/5.3/5.5 theo tung su kien)
   ============================================================================ */
SELECT COUNT(*) INTO @soTrigger
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = DATABASE()
  AND TRIGGER_NAME IN (
    'TR_ChiTietThue_ChanTrungLap_Ins', 'TR_ChiTietThue_ChanTrungLap_Upd',
    'TR_DangKyDichVu_ApDungBacThang',
    'TR_NhatKyDichVu_KiemTraHopLe_Ins', 'TR_NhatKyDichVu_KiemTraHopLe_Upd',
    'TR_CongTy_ChanXoa', 'TR_ToaNha_ChanXoa',
    'TR_ChiTietThue_DongBoDienTich_Ins', 'TR_ChiTietThue_DongBoDienTich_Upd', 'TR_ChiTietThue_DongBoDienTich_Del');

SELECT IF(@soTrigger = 10, '[TV5] HOAN THANH - 10/10 trigger vat ly (6 quy tac) da tao thanh cong.',
          '[TV5] THAT BAI - khong du trigger. Kiem tra log.') AS KetQua;
