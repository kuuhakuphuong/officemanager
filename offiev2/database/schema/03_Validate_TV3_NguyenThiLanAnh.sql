/* ============================================================================
   TV3 - Kiem tra cau truc, du lieu mau, 32 ca vi pham rang buoc (MySQL 8.0)
   Loi tu kiem tra: SIGNAL SQLSTATE 45000 voi MYSQL_ERRNO 51xxx (cung ma voi ban SQL Server).
   Ca vi pham rang buoc: ma loi la errno cua MySQL (1048, 1062, 1452, 3819).
   ============================================================================ */
USE QLToaNha_BCNF;

DROP PROCEDURE IF EXISTS usp_TV3_KiemTra;

DELIMITER $$
CREATE PROCEDURE usp_TV3_KiemTra()
BEGIN
    DECLARE v_Count INT DEFAULT 0;
    DECLARE v_Sum DECIMAL(18,2) DEFAULT 0;
    DECLARE v_Total INT DEFAULT 0;
    DECLARE v_i INT DEFAULT 1;
    DECLARE v_Ten VARCHAR(100);
    DECLARE v_Expected INT;
    DECLARE v_Object VARCHAR(128);
    DECLARE v_Actual INT DEFAULT 0;
    DECLARE v_Msg VARCHAR(1000) DEFAULT '';
    DECLARE v_Text VARCHAR(1000);
    DECLARE v_HoaDon INT;

    -- ---------------------------------------------------------------- Cau truc
    SELECT COUNT(*) INTO v_Count FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE';
    IF v_Count <> 18 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong du 18 bang nghiep vu.', MYSQL_ERRNO = 51100;
    END IF;

    SELECT COUNT(*) INTO v_Count FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND CONSTRAINT_TYPE = 'PRIMARY KEY';
    IF v_Count <> 18 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong du 18 PK.', MYSQL_ERRNO = 51101;
    END IF;

    SELECT COUNT(*) INTO v_Count FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE();
    IF v_Count <> 23 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong du 23 FK.', MYSQL_ERRNO = 51102;
    END IF;

    SELECT COUNT(*) INTO v_Count FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'CK_HoaDonThang_ThanhToan' AND CONSTRAINT_TYPE = 'CHECK';
    SELECT v_Count + (SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'HoaDonThang' AND COLUMN_NAME = 'TrangThai'
            AND DATA_TYPE = 'varchar' AND CHARACTER_MAXIMUM_LENGTH = 20 AND IS_NULLABLE = 'NO'
            AND COLUMN_DEFAULT = 'CHUA_THANH_TOAN')
        + (SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'HoaDonThang' AND COLUMN_NAME = 'NgayThanhToan'
            AND DATA_TYPE = 'date' AND IS_NULLABLE = 'YES')
        + (SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'HoaDonThang' AND COLUMN_NAME = 'NguoiThu'
            AND DATA_TYPE = 'varchar' AND CHARACTER_MAXIMUM_LENGTH = 100 AND IS_NULLABLE = 'YES')
        INTO v_Count;
    IF v_Count <> 4 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Thieu/sai cot, DEFAULT hoac CHECK thanh toan; chay script 05.', MYSQL_ERRNO = 51114;
    END IF;

    SELECT COUNT(*) INTO v_Count FROM information_schema.VIEWS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'V_ChiTietHoaDon';
    SELECT v_Count + (SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ChiTietHoaDon' AND COLUMN_NAME = 'SoTien') INTO v_Count;
    IF v_Count <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sai view V_ChiTietHoaDon hoac con cot SoTien trong bang ChiTietHoaDon.', MYSQL_ERRNO = 51113;
    END IF;

    SELECT COUNT(*) INTO v_Count FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'MaHoaDon' AND DATA_TYPE = 'int'
        AND TABLE_NAME IN ('HoaDonThang', 'ChiTietHoaDon');
    IF v_Count <> 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sai kieu MaHoaDon: phai la INT o ca bang cha va bang con.', MYSQL_ERRNO = 51113;
    END IF;

    -- ---------------------------------------------------------------- Du lieu mau
    IF (SELECT COUNT(*) FROM ChiTietSuDungNV) <> 7320
        OR (SELECT MIN(NgaySuDung) FROM ChiTietSuDungNV) <> DATE '2026-08-01'
        OR (SELECT MAX(NgaySuDung) FROM ChiTietSuDungNV) <> DATE '2026-09-30'
        OR (SELECT COUNT(DISTINCT NgaySuDung) FROM ChiTietSuDungNV) <> 61 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sai khoi luong hoac khoang thoi gian log.', MYSQL_ERRNO = 51105;
    END IF;

    IF EXISTS (
        SELECT 1 FROM ChiTietSuDungNV AS logdv
        JOIN NhanVienCongTy AS nv ON nv.MaNVCT = logdv.MaNVCT
        JOIN DichVu AS dv ON dv.MaDichVu = logdv.MaDichVu
        JOIN LoaiDichVu AS loai ON loai.MaLoaiDV = dv.MaLoaiDV
        WHERE loai.KieuTinhPhi <> 'LUOT' OR logdv.DonGiaApDung <> dv.DonGiaCoBan
            OR logdv.NgaySuDung < nv.NgayVaoLam
            OR (nv.NgayNghiViec IS NOT NULL AND logdv.NgaySuDung > nv.NgayNghiViec)
            OR NOT EXISTS (SELECT 1 FROM SuDungDichVu AS dk
                WHERE dk.MaCongTy = nv.MaCongTy AND dk.MaDichVu = logdv.MaDichVu
                    AND logdv.NgaySuDung >= dk.NgayBatDau
                    AND (dk.NgayKetThuc IS NULL OR logdv.NgaySuDung <= dk.NgayKetThuc))
            OR NOT EXISTS (SELECT 1 FROM HopDongThue AS hd
                JOIN VanPhong AS vp ON vp.MaVanPhong = hd.MaVanPhong
                WHERE hd.MaCongTy = nv.MaCongTy AND vp.MaToaNha = dv.MaToaNha
                    AND logdv.NgaySuDung >= hd.NgayBatDau
                    AND (hd.NgayKetThuc IS NULL OR logdv.NgaySuDung <= hd.NgayKetThuc))
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Log khong khop dang ky, hop dong, gia hoac thoi gian lam viec.', MYSQL_ERRNO = 51106;
    END IF;

    IF EXISTS (SELECT 1 FROM VanPhong AS vp JOIN ToaNha AS tn ON tn.MaToaNha = vp.MaToaNha WHERE vp.Tang > tn.SoTang)
        OR EXISTS (SELECT 1 FROM NhanVienToaNha AS nv JOIN NhanVienToaNha AS ql ON ql.MaNVTN = nv.MaQuanLy
            WHERE nv.MaToaNha <> ql.MaToaNha OR ql.LoaiNV <> 'QUAN_LY')
        OR EXISTS (SELECT 1 FROM PhanCongNVTN AS pc JOIN NhanVienToaNha AS nv ON nv.MaNVTN = pc.MaNVTN
            LEFT JOIN DichVu AS dv ON dv.MaDichVu = pc.MaDichVu
            WHERE (nv.LoaiNV = 'QUAN_LY' AND pc.MaDichVu IS NOT NULL)
                OR (nv.LoaiNV = 'DICH_VU' AND (pc.MaDichVu IS NULL OR nv.MaToaNha <> dv.MaToaNha))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sai tang hoac phan cong/quan ly khac toa nha.', MYSQL_ERRNO = 51107;
    END IF;

    IF EXISTS (
        SELECT 1 FROM HopDongThue AS hd1 JOIN HopDongThue AS hd2
            ON hd1.MaVanPhong = hd2.MaVanPhong AND hd1.MaHopDong < hd2.MaHopDong
        WHERE hd1.NgayBatDau <= COALESCE(hd2.NgayKetThuc, DATE '9999-12-31')
            AND hd2.NgayBatDau <= COALESCE(hd1.NgayKetThuc, DATE '9999-12-31')
    ) OR EXISTS (
        SELECT 1 FROM SuDungDichVu AS dk1 JOIN SuDungDichVu AS dk2
            ON dk1.MaCongTy = dk2.MaCongTy AND dk1.MaDichVu = dk2.MaDichVu AND dk1.NgayBatDau < dk2.NgayBatDau
        WHERE dk2.NgayBatDau <= COALESCE(dk1.NgayKetThuc, DATE '9999-12-31')
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Co khoang thoi gian hop dong/dang ky chong nhau.', MYSQL_ERRNO = 51108;
    END IF;

    IF EXISTS (
        SELECT 1 FROM HoaDonThang AS hd
        WHERE COALESCE((
            SELECT SUM(CAST(logdv.SoLuot AS DECIMAL(18,2)) * logdv.DonGiaApDung)
            FROM ChiTietSuDungNV AS logdv
            JOIN NhanVienCongTy AS nv ON nv.MaNVCT = logdv.MaNVCT
            JOIN DichVu AS dv ON dv.MaDichVu = logdv.MaDichVu
            WHERE nv.MaCongTy = hd.MaCongTy AND dv.MaToaNha = hd.MaToaNha
                AND YEAR(logdv.NgaySuDung) = hd.Nam AND MONTH(logdv.NgaySuDung) = hd.Thang
        ), -1) <> COALESCE((
            SELECT SUM(ct.SoTien) FROM V_ChiTietHoaDon AS ct
            WHERE ct.MaHoaDon = hd.MaHoaDon AND ct.LoaiKhoan = 'DICH_VU_LUOT'
        ), -2)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tien dich vu theo luot tren hoa don khong khop log.', MYSQL_ERRNO = 51109;
    END IF;

    SELECT SUM(SoTien) INTO v_Sum FROM V_ChiTietHoaDon;
    IF v_Sum <> 725400000 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tong hoa don khong khop bo du lieu mau.', MYSQL_ERRNO = 51110;
    END IF;
    SELECT SUM(LuongCoBan + TienThuong) INTO v_Sum FROM LuongThang;
    IF v_Sum <> 208137000 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tong luong khong khop bo du lieu mau.', MYSQL_ERRNO = 51110;
    END IF;

    -- ---------------------------------------------------------------- 32 ca vi pham rang buoc
    DROP TEMPORARY TABLE IF EXISTS tmp_CaKiemThu;
    CREATE TEMPORARY TABLE tmp_CaKiemThu (
        CaseID INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        Ten VARCHAR(100) NOT NULL,
        CauLenh TEXT NOT NULL,
        MaLoi INT NOT NULL,
        DoiTuong VARCHAR(128) NOT NULL
    );
    INSERT INTO tmp_CaKiemThu(Ten, CauLenh, MaLoi, DoiTuong) VALUES
    ('PK', "INSERT INTO ToaNha VALUES ('TN01', 'Trung PK', 'Mau', 5)", 1062, 'PRIMARY'),
    ('FK', "INSERT INTO VanPhong(MaVanPhong, MaToaNha, MaViTri, Tang, DienTich) VALUES ('TEST', 'MISSING', 'VT_TRONG', 1, 80)", 1452, 'FK_VanPhong_ToaNha'),
    ('NOT NULL', "UPDATE CongTy SET MaSoThue = NULL WHERE MaCongTy = 'CT01'", 1048, 'MaSoThue'),
    ('UNIQUE MST', "UPDATE CongTy SET MaSoThue = '0101234501' WHERE MaCongTy = 'CT02'", 1062, 'UQ_CongTy_MaSoThue'),
    ('MST letters', "UPDATE CongTy SET MaSoThue = '010900000A' WHERE MaCongTy = 'CT01'", 3819, 'CK_CongTy_MST'),
    ('MST short', "UPDATE CongTy SET MaSoThue = '123456789' WHERE MaCongTy = 'CT01'", 3819, 'CK_CongTy_MST'),
    ('MST trailing space', "UPDATE CongTy SET MaSoThue = '123456789 ' WHERE MaCongTy = 'CT01'", 3819, 'CK_CongTy_MST'),
    ('MST branch letters', "UPDATE CongTy SET MaSoThue = '0109000001-00A' WHERE MaCongTy = 'CT01'", 3819, 'CK_CongTy_MST'),
    ('Area zero', "UPDATE VanPhong SET DienTich = 0 WHERE MaVanPhong = 'VP01'", 3819, 'CK_VanPhong_DienTich'),
    ('Area negative', "UPDATE VanPhong SET DienTich = -1 WHERE MaVanPhong = 'VP01'", 3819, 'CK_VanPhong_DienTich'),
    ('Lease reversed dates', "UPDATE HopDongThue SET NgayKetThuc = DATE_SUB(NgayBatDau, INTERVAL 1 DAY) WHERE MaHopDong = 'HD01'", 3819, 'CK_HopDongThue_Ngay'),
    ('Service reversed dates', "UPDATE SuDungDichVu SET NgayKetThuc = DATE_SUB(NgayBatDau, INTERVAL 1 DAY) WHERE MaCongTy = 'CT01'", 3819, 'CK_SuDungDichVu_Ngay'),
    ('Service base price zero', "UPDATE DichVu SET DonGiaCoBan = 0 WHERE MaDichVu = 'AN01'", 3819, 'CK_DichVu_DonGia'),
    ('Headcount zero', "UPDATE ThamSo SET GiaTri = 0 WHERE TenThamSo = 'NGUONG_NGUOI'", 3819, 'CK_ThamSo_SoNguoi'),
    ('Headcount fractional', "UPDATE ThamSo SET GiaTri = 1.5 WHERE TenThamSo = 'BUOC_NGUOI'", 3819, 'CK_ThamSo_SoNguoi'),
    ('Visits zero', "UPDATE ChiTietSuDungNV SET SoLuot = 0 WHERE MaSuDung = (SELECT x.m FROM (SELECT MIN(MaSuDung) AS m FROM ChiTietSuDungNV) AS x)", 3819, 'CK_ChiTietSuDungNV_SoLuot'),
    ('Price negative', "UPDATE ChiTietSuDungNV SET DonGiaApDung = -1 WHERE MaSuDung = (SELECT x.m FROM (SELECT MIN(MaSuDung) AS m FROM ChiTietSuDungNV) AS x)", 3819, 'CK_ChiTietSuDungNV_DonGia'),
    ('Invoice XOR both', "UPDATE ChiTietHoaDon SET MaDichVu = 'AN01' WHERE MaChiTiet = (SELECT x.m FROM (SELECT MIN(MaChiTiet) AS m FROM ChiTietHoaDon WHERE LoaiKhoan = 'THUE_VAN_PHONG') AS x)", 3819, 'CK_ChiTietHoaDon_Loai'),
    ('Invoice XOR neither', "UPDATE ChiTietHoaDon SET MaVanPhong = NULL WHERE MaChiTiet = (SELECT x.m FROM (SELECT MIN(MaChiTiet) AS m FROM ChiTietHoaDon WHERE LoaiKhoan = 'THUE_VAN_PHONG') AS x)", 3819, 'CK_ChiTietHoaDon_Loai'),
    ('Invoice ratio', "UPDATE ChiTietHoaDon SET TyLeNgay = 1.1 WHERE MaChiTiet = (SELECT x.m FROM (SELECT MIN(MaChiTiet) AS m FROM ChiTietHoaDon) AS x)", 3819, 'CK_ChiTietHoaDon_TyLe'),
    ('Month invalid', "UPDATE PhanCongNVTN SET Thang = 13 WHERE MaNVTN = 'QL01'", 3819, 'CK_PhanCongNVTN_Thang'),
    ('Composite payroll FK', "INSERT INTO LuongThang VALUES ('QL01', 7, 2026, 18000000, 0)", 1452, 'FK_LuongThang_PhanCong'),
    ('Manager self-reference', "UPDATE NhanVienToaNha SET MaQuanLy = MaNVTN WHERE MaNVTN = 'NVAN01'", 3819, 'CK_NhanVienToaNha_QuanLy'),
    ('Unique daily log', "INSERT INTO ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, DonGiaApDung) SELECT MaNVCT, MaDichVu, NgaySuDung, DonGiaApDung FROM ChiTietSuDungNV LIMIT 1", 1062, 'UQ_ChiTietSuDungNV_Ngay'),
    ('Unique invoice period', "INSERT INTO HoaDonThang(MaCongTy, MaToaNha, Thang, Nam) VALUES ('CT01', 'TN01', 8, 2026)", 1062, 'UQ_HoaDonThang_Ky'),
    ('Payment invalid status', "UPDATE HoaDonThang SET TrangThai = 'INVALID'", 3819, 'CK_HoaDonThang_ThanhToan'),
    ('Payment NULL status', "UPDATE HoaDonThang SET TrangThai = NULL", 1048, 'TrangThai'),
    ('Payment missing date', "UPDATE HoaDonThang SET TrangThai = 'DA_THANH_TOAN', NgayThanhToan = NULL", 3819, 'CK_HoaDonThang_ThanhToan'),
    ('Payment unpaid with date', "UPDATE HoaDonThang SET TrangThai = 'CHUA_THANH_TOAN', NgayThanhToan = NgayLap, NguoiThu = NULL", 3819, 'CK_HoaDonThang_ThanhToan'),
    ('Payment before invoice', "UPDATE HoaDonThang SET TrangThai = 'DA_THANH_TOAN', NgayThanhToan = DATE_SUB(NgayLap, INTERVAL 1 DAY)", 3819, 'CK_HoaDonThang_ThanhToan'),
    ('Payment unpaid collector', "UPDATE HoaDonThang SET TrangThai = 'CHUA_THANH_TOAN', NgayThanhToan = NULL, NguoiThu = 'Cashier'", 3819, 'CK_HoaDonThang_ThanhToan'),
    ('Payment blank collector', "UPDATE HoaDonThang SET TrangThai = 'DA_THANH_TOAN', NgayThanhToan = NgayLap, NguoiThu = '   '", 3819, 'CK_HoaDonThang_ThanhToan');

    SELECT COUNT(*) INTO v_Total FROM tmp_CaKiemThu;
    WHILE v_i <= v_Total DO
        SELECT Ten, MaLoi, DoiTuong INTO v_Ten, v_Expected, v_Object FROM tmp_CaKiemThu WHERE CaseID = v_i;
        SELECT CauLenh INTO @CauLenhKiemThu FROM tmp_CaKiemThu WHERE CaseID = v_i;
        SET v_Actual = 0;
        SET v_Msg = '';
        START TRANSACTION;
        BEGIN
            -- Handler chi phu trong khoi nay de khong bat nham loi cua chinh procedure.
            DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
            BEGIN
                GET DIAGNOSTICS CONDITION 1 v_Actual = MYSQL_ERRNO, v_Msg = MESSAGE_TEXT;
            END;
            PREPARE stKiemThu FROM @CauLenhKiemThu;
            EXECUTE stKiemThu;
            DEALLOCATE PREPARE stKiemThu;
        END;
        ROLLBACK;
        IF v_Actual <> v_Expected OR LOCATE(v_Object, v_Msg) = 0 THEN
            SET v_Text = CONCAT('FAIL ', v_Ten, ': expected ', v_Expected, ' / ', v_Object, '; actual ', v_Actual, ' / ', LEFT(v_Msg, 200));
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Text, MYSQL_ERRNO = 51111;
        END IF;
        SET v_i = v_i + 1;
    END WHILE;
    DROP TEMPORARY TABLE IF EXISTS tmp_CaKiemThu;

    -- ---------------------------------------------------------------- Ca hop le (mac dinh, cap nhat cung ngay) - rollback
    START TRANSACTION;
    INSERT INTO HoaDonThang(MaCongTy, MaToaNha, Thang, Nam) VALUES ('CT01', 'TN01', 1, 1900);
    SET v_HoaDon = LAST_INSERT_ID();
    SELECT COUNT(*) INTO v_Count FROM HoaDonThang
    WHERE MaHoaDon = v_HoaDon AND TrangThai = 'CHUA_THANH_TOAN' AND NgayThanhToan IS NULL AND NguoiThu IS NULL;
    IF v_Count <> 1 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'DEFAULT thanh toan khong dung.', MYSQL_ERRNO = 51115;
    END IF;
    UPDATE HoaDonThang SET TrangThai = 'DA_THANH_TOAN', NgayThanhToan = NgayLap, NguoiThu = 'Test cashier'
    WHERE MaHoaDon = v_HoaDon;
    UPDATE HoaDonThang SET NguoiThu = NULL WHERE MaHoaDon = v_HoaDon;
    UPDATE HoaDonThang SET TrangThai = 'CHUA_THANH_TOAN', NgayThanhToan = NULL WHERE MaHoaDon = v_HoaDon;
    UPDATE CongTy SET MaSoThue = '0109000001-001' WHERE MaCongTy = 'CT01';
    -- TV6 sua: ba truong hop cung ngay phai duoc chap nhan; toan bo thay doi se rollback.
    UPDATE HopDongThue SET NgayKetThuc = NgayBatDau WHERE MaHopDong = 'HD01';
    UPDATE SuDungDichVu SET NgayKetThuc = NgayBatDau WHERE MaCongTy = 'CT01';
    UPDATE NhanVienCongTy SET NgayNghiViec = NgayVaoLam WHERE MaNVCT = 'NVCT001';
    UPDATE HopDongThue SET NgayKetThuc = NULL WHERE MaHopDong = 'HD01';
    INSERT INTO ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, DonGiaApDung)
    VALUES ('NVCT001', 'AN01', '2026-10-01', 35000);
    SELECT COUNT(*) INTO v_Count FROM ChiTietSuDungNV
    WHERE MaNVCT = 'NVCT001' AND MaDichVu = 'AN01' AND NgaySuDung = DATE '2026-10-01' AND SoLuot = 1;
    IF v_Count <> 1 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'DEFAULT SoLuot khong hoat dong.', MYSQL_ERRNO = 51112;
    END IF;
    ROLLBACK;
END$$
DELIMITER ;

CALL usp_TV3_KiemTra();
DROP PROCEDURE IF EXISTS usp_TV3_KiemTra;

SELECT 'PASS: 18 bang, 18 PK, 23 FK, doi chieu du lieu, 32 ca vi pham rang buoc, ca hop le (mac dinh/cap nhat)' AS KetQua;
