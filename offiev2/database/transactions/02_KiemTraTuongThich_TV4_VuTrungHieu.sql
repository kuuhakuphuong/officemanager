/* Kiem tra tuong thich metadata cho TV4 (MySQL). Loi 51610-51613 dung cung ma voi ban SQL Server. */
USE QLToaNha_BCNF;

DROP PROCEDURE IF EXISTS usp_TV4_KiemTraTuongThich;

DELIMITER $$
CREATE PROCEDURE usp_TV4_KiemTraTuongThich()
BEGIN
    IF (SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE') <> 18 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Can dung 18 bang nghiep vu cua DDL moi TV3.', MYSQL_ERRNO = 51610;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'ChiTietHoaDon' AND COLUMN_NAME = 'SoTien')
        OR NOT EXISTS (SELECT 1 FROM information_schema.VIEWS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'V_ChiTietHoaDon') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Can schema moi: SoTien o view V_ChiTietHoaDon, khong o bang ChiTietHoaDon.', MYSQL_ERRNO = 51611;
    END IF;
    IF (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()
        AND COLUMN_NAME = 'MaHoaDon' AND DATA_TYPE = 'int'
        AND TABLE_NAME IN ('HoaDonThang', 'ChiTietHoaDon')) <> 2
        OR NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'HoaDonThang' AND COLUMN_NAME = 'MaHoaDon' AND EXTRA LIKE '%auto_increment%') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'MaHoaDon phai INT o ca bang cha va bang con.', MYSQL_ERRNO = 51612;
    END IF;
    IF (SELECT COUNT(*) FROM ThamSo WHERE TenThamSo IN ('NGUONG_NGUOI', 'BUOC_NGUOI',
        'NGUONG_DIEN_TICH', 'BUOC_DIEN_TICH', 'TY_LE_TANG_GIA')) <> 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Thieu bo ten tham so moi TV3.', MYSQL_ERRNO = 51613;
    END IF;
END$$
DELIMITER ;

CALL usp_TV4_KiemTraTuongThich();
DROP PROCEDURE IF EXISTS usp_TV4_KiemTraTuongThich;

SELECT 'Khop metadata chinh cua ban 18 bang moi' AS KetQua;
