/* ============================================================================
   VU TRUNG HIEU (TV4) - 5 STORED PROCEDURE GIAO DICH (ban MySQL 8.0)
   Khac biet voi ban SQL Server:
     - Table-valued parameter -> tham so JSON, doc bang JSON_TABLE.
     - sp_getapplock (khoa theo transaction) -> GET_LOCK, duoc giai phong
       o cuoi moi thu tuc va trong handler loi.
     - OUTPUT inserted -> doc lai hoa don vua tao qua (MaCongTy, MaToaNha, Thang, Nam).
     - Thu tuc tra ve dung 1 result set de ung dung doc qua CALL.
   Ma loi van la 51xxx (SIGNAL MYSQL_ERRNO), thong bao toi da 128 ky tu.
   ============================================================================ */
USE QLToaNha_BCNF;

DELIMITER $$

/* ----------------------------------------------------------------------------
   T1: Ky hop dong thue mat bang nhieu phong (mot giao dich)
   p_DanhSachPhong: JSON mang chuoi, vi du '["VP01","VP02"]'
   ---------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS USP_Trx_KyHopDongThueMatBang$$
CREATE PROCEDURE USP_Trx_KyHopDongThueMatBang(
    IN p_MaCongTy VARCHAR(20), IN p_MaToaNha VARCHAR(20),
    IN p_NgayBatDau DATE, IN p_NgayKetThuc DATE,
    IN p_DanhSachPhong JSON)
BEGIN
    DECLARE v_Khoa INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DO RELEASE_LOCK('TV4_NghiepVu');
        RESIGNAL;
    END;

    SET v_Khoa = GET_LOCK('TV4_NghiepVu', 10);
    IF v_Khoa IS NULL OR v_Khoa <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong lay duoc khoa nghiep vu. Thu lai sau.', MYSQL_ERRNO = 51001;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_Phong;
    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_Ma;
    CREATE TEMPORARY TABLE tmp_TV4_Phong (MaVanPhong VARCHAR(20) NOT NULL PRIMARY KEY);
    CREATE TEMPORARY TABLE tmp_TV4_Ma (
        MaVanPhong VARCHAR(20) NOT NULL PRIMARY KEY,
        MaHopDong VARCHAR(20) NOT NULL,
        UNIQUE KEY UQ_tmp_TV4_Ma_HopDong (MaHopDong)
    );
    INSERT INTO tmp_TV4_Phong (MaVanPhong)
    SELECT jt.MaVanPhong FROM JSON_TABLE(p_DanhSachPhong, '$[*]' COLUMNS (MaVanPhong VARCHAR(20) PATH '$')) AS jt;

    /* TV6 sua: ngay ket thuc bang ngay bat dau duoc chap nhan nhu DDL TV3. */
    IF p_NgayBatDau IS NULL OR (p_NgayKetThuc IS NOT NULL AND p_NgayKetThuc < p_NgayBatDau)
        OR NOT EXISTS (SELECT 1 FROM tmp_TV4_Phong) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ngay thue hoac danh sach phong khong hop le.', MYSQL_ERRNO = 51101;
    END IF;

    START TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM CongTy WHERE MaCongTy = p_MaCongTy)
        OR NOT EXISTS (SELECT 1 FROM ToaNha WHERE MaToaNha = p_MaToaNha) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cong ty hoac toa nha khong ton tai.', MYSQL_ERRNO = 51102;
    END IF;
    IF EXISTS (SELECT 1 FROM tmp_TV4_Phong p LEFT JOIN VanPhong v ON v.MaVanPhong = p.MaVanPhong
        WHERE v.MaVanPhong IS NULL OR v.MaToaNha <> p_MaToaNha) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Phong phai ton tai va thuoc dung toa nha.', MYSQL_ERRNO = 51103;
    END IF;
    IF EXISTS (SELECT 1 FROM HoaDonThang h WHERE h.MaToaNha = p_MaToaNha
        AND MAKEDATE(h.Nam, 1) + INTERVAL (h.Thang - 1) MONTH <= COALESCE(p_NgayKetThuc, DATE '9999-12-31')
        AND LAST_DAY(MAKEDATE(h.Nam, 1) + INTERVAL (h.Thang - 1) MONTH) >= p_NgayBatDau) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khoang thue cham vao ky da co hoa don.', MYSQL_ERRNO = 51105;
    END IF;
    IF EXISTS (SELECT 1 FROM tmp_TV4_Phong p JOIN HopDongThue h ON h.MaVanPhong = p.MaVanPhong
        WHERE h.NgayBatDau <= COALESCE(p_NgayKetThuc, DATE '9999-12-31')
            AND COALESCE(h.NgayKetThuc, DATE '9999-12-31') >= p_NgayBatDau
        FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Co phong trung lich thue. Huy toan bo lo.', MYSQL_ERRNO = 51106;
    END IF;

    /* Ma hop dong rieng cho tung dong thue; PK/UNIQUE van chan neu ngau nhien trung ma. */
    INSERT INTO tmp_TV4_Ma (MaVanPhong, MaHopDong)
    SELECT MaVanPhong, CONCAT('H', LEFT(REPLACE(UUID(), '-', ''), 19)) FROM tmp_TV4_Phong;

    INSERT INTO HopDongThue (MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc)
    SELECT MaHopDong, p_MaCongTy, MaVanPhong, p_NgayBatDau, p_NgayKetThuc FROM tmp_TV4_Ma;

    COMMIT;
    DO RELEASE_LOCK('TV4_NghiepVu');
    SELECT MaHopDong, MaVanPhong FROM tmp_TV4_Ma ORDER BY MaVanPhong;

    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_Ma;
    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_Phong;
END$$

/* ----------------------------------------------------------------------------
   T2: Ghi nhat ky su dung dich vu luot (ca lo hoac khong ghi gi)
   p_DanhSach: JSON mang doi tuong {MaNVCT, MaDichVu, NgaySuDung, SoLuot}
   ---------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS USP_Trx_GhiNhanDichVuHangNgay$$
CREATE PROCEDURE USP_Trx_GhiNhanDichVuHangNgay(IN p_DanhSach JSON)
BEGIN
    DECLARE v_Khoa INT;
    DECLARE v_SoDong INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DO RELEASE_LOCK('TV4_NghiepVu');
        RESIGNAL;
    END;

    SET v_Khoa = GET_LOCK('TV4_NghiepVu', 10);
    IF v_Khoa IS NULL OR v_Khoa <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong lay duoc khoa nghiep vu. Thu lai sau.', MYSQL_ERRNO = 51001;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_SuDung;
    CREATE TEMPORARY TABLE tmp_TV4_SuDung (
        MaNVCT VARCHAR(20) NOT NULL,
        MaDichVu VARCHAR(20) NOT NULL,
        NgaySuDung DATE NOT NULL,
        SoLuot INT NOT NULL,
        PRIMARY KEY (MaNVCT, MaDichVu, NgaySuDung)
    );
    INSERT INTO tmp_TV4_SuDung (MaNVCT, MaDichVu, NgaySuDung, SoLuot)
    SELECT jt.MaNVCT, jt.MaDichVu, jt.NgaySuDung, jt.SoLuot
    FROM JSON_TABLE(p_DanhSach, '$[*]' COLUMNS (
        MaNVCT VARCHAR(20) PATH '$.MaNVCT',
        MaDichVu VARCHAR(20) PATH '$.MaDichVu',
        NgaySuDung DATE PATH '$.NgaySuDung',
        SoLuot INT PATH '$.SoLuot')) AS jt;

    START TRANSACTION;
    -- Tach thanh hai IF: MySQL khong cho mot bang tam duoc tham chieu hai lan trong cung mot cau lenh.
    IF NOT EXISTS (SELECT 1 FROM tmp_TV4_SuDung) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lo rong, so luot khong duong hoac ngay su dung trong tuong lai.', MYSQL_ERRNO = 51201;
    END IF;
    IF EXISTS (SELECT 1 FROM tmp_TV4_SuDung WHERE SoLuot <= 0 OR NgaySuDung > CURDATE()) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lo rong, so luot khong duong hoac ngay su dung trong tuong lai.', MYSQL_ERRNO = 51201;
    END IF;
    IF EXISTS (SELECT 1 FROM tmp_TV4_SuDung x
        LEFT JOIN NhanVienCongTy n ON n.MaNVCT = x.MaNVCT
        LEFT JOIN DichVu d ON d.MaDichVu = x.MaDichVu
        LEFT JOIN LoaiDichVu l ON l.MaLoaiDV = d.MaLoaiDV
        WHERE n.MaNVCT IS NULL OR d.MaDichVu IS NULL OR l.KieuTinhPhi <> 'LUOT'
            OR x.NgaySuDung < n.NgayVaoLam
            OR x.NgaySuDung > COALESCE(n.NgayNghiViec, DATE '9999-12-31')
            OR NOT EXISTS (SELECT 1 FROM SuDungDichVu s WHERE s.MaCongTy = n.MaCongTy
                AND s.MaDichVu = x.MaDichVu AND s.NgayBatDau <= x.NgaySuDung
                AND COALESCE(s.NgayKetThuc, DATE '9999-12-31') >= x.NgaySuDung)
            OR NOT EXISTS (SELECT 1 FROM HopDongThue h JOIN VanPhong v ON v.MaVanPhong = h.MaVanPhong
                WHERE h.MaCongTy = n.MaCongTy AND v.MaToaNha = d.MaToaNha
                AND h.NgayBatDau <= x.NgaySuDung
                AND COALESCE(h.NgayKetThuc, DATE '9999-12-31') >= x.NgaySuDung)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nhan vien, dich vu, dang ky hoac hop dong khong hop le vao ngay su dung.', MYSQL_ERRNO = 51202;
    END IF;
    IF EXISTS (SELECT 1 FROM tmp_TV4_SuDung x JOIN DichVu d ON d.MaDichVu = x.MaDichVu
        JOIN HoaDonThang k ON k.MaToaNha = d.MaToaNha
            AND k.Thang = MONTH(x.NgaySuDung) AND k.Nam = YEAR(x.NgaySuDung)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong them nhat ky vao ky da phat hanh hoa don.', MYSQL_ERRNO = 51203;
    END IF;
    IF EXISTS (SELECT 1 FROM tmp_TV4_SuDung x JOIN ChiTietSuDungNV c
        ON c.MaNVCT = x.MaNVCT AND c.MaDichVu = x.MaDichVu AND c.NgaySuDung = x.NgaySuDung
        FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lo co nhat ky da duoc ghi nhan. Khong cong don ngam.', MYSQL_ERRNO = 51204;
    END IF;

    INSERT INTO ChiTietSuDungNV (MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung)
    SELECT x.MaNVCT, x.MaDichVu, x.NgaySuDung, x.SoLuot, d.DonGiaCoBan
    FROM tmp_TV4_SuDung x JOIN DichVu d ON d.MaDichVu = x.MaDichVu;
    SET v_SoDong = ROW_COUNT();

    COMMIT;
    DO RELEASE_LOCK('TV4_NghiepVu');
    SELECT v_SoDong AS SoDongDaGhi;

    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_SuDung;
END$$

/* ----------------------------------------------------------------------------
   T3: Phat hanh hoa don thang cho mot toa nha (tien thue + dich vu THANG + luot)
   ---------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS USP_Trx_PhatHanhHoaDonThang$$
CREATE PROCEDURE USP_Trx_PhatHanhHoaDonThang(IN p_MaToaNha VARCHAR(20), IN p_Thang TINYINT, IN p_Nam SMALLINT)
BEGIN
    DECLARE v_Khoa INT;
    DECLARE v_Tu DATE;
    DECLARE v_Den DATE;
    DECLARE v_NguongNguoi DECIMAL(18,6);
    DECLARE v_BuocNguoi DECIMAL(18,6);
    DECLARE v_NguongDT DECIMAL(18,6);
    DECLARE v_BuocDT DECIMAL(18,6);
    DECLARE v_TyLe DECIMAL(18,6);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DO RELEASE_LOCK('TV4_NghiepVu');
        RESIGNAL;
    END;

    SET v_Khoa = GET_LOCK('TV4_NghiepVu', 10);
    IF v_Khoa IS NULL OR v_Khoa <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong lay duoc khoa nghiep vu. Thu lai sau.', MYSQL_ERRNO = 51001;
    END IF;

    IF p_Thang IS NULL OR p_Thang NOT BETWEEN 1 AND 12 OR p_Nam IS NULL OR p_Nam NOT BETWEEN 1900 AND 9999 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Thang hoac nam khong hop le.', MYSQL_ERRNO = 51301;
    END IF;
    SET v_Tu = MAKEDATE(p_Nam, 1) + INTERVAL (p_Thang - 1) MONTH;
    SET v_Den = LAST_DAY(v_Tu);
    IF v_Den >= CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chi chot khi thang da ket thuc.', MYSQL_ERRNO = 51302;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_Ngay;
    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_Dong;
    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_PhiRaw;
    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_Phi;
    CREATE TEMPORARY TABLE tmp_TV4_Ngay (Ngay DATE NOT NULL PRIMARY KEY);
    CREATE TEMPORARY TABLE tmp_TV4_Dong (
        MaCongTy VARCHAR(20) NOT NULL,
        LoaiKhoan VARCHAR(20) NOT NULL,
        MaVanPhong VARCHAR(20) NULL,
        MaDichVu VARCHAR(20) NULL,
        SoLuong DECIMAL(12,2) NOT NULL,
        DonGiaApDung DECIMAL(18,2) NOT NULL,
        TyLeNgay DECIMAL(12,10) NOT NULL
    );

    START TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM ToaNha WHERE MaToaNha = p_MaToaNha) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Toa nha khong ton tai.', MYSQL_ERRNO = 51303;
    END IF;
    IF EXISTS (SELECT 1 FROM HoaDonThang WHERE MaToaNha = p_MaToaNha AND Thang = p_Thang AND Nam = p_Nam FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ky da co hoa don. Khong ghi de hoac lap bo sung ngam.', MYSQL_ERRNO = 51304;
    END IF;

    SELECT
        MAX(CASE WHEN TenThamSo = 'NGUONG_NGUOI' THEN GiaTri END),
        MAX(CASE WHEN TenThamSo = 'BUOC_NGUOI' THEN GiaTri END),
        MAX(CASE WHEN TenThamSo = 'NGUONG_DIEN_TICH' THEN GiaTri END),
        MAX(CASE WHEN TenThamSo = 'BUOC_DIEN_TICH' THEN GiaTri END),
        MAX(CASE WHEN TenThamSo = 'TY_LE_TANG_GIA' THEN GiaTri END)
    INTO v_NguongNguoi, v_BuocNguoi, v_NguongDT, v_BuocDT, v_TyLe
    FROM ThamSo;
    IF v_NguongNguoi IS NULL OR v_BuocNguoi IS NULL OR v_NguongDT IS NULL OR v_BuocDT IS NULL OR v_TyLe IS NULL
        OR v_NguongNguoi < 1 OR v_BuocNguoi <= 0 OR v_NguongDT < 0 OR v_BuocDT <= 0 OR v_TyLe NOT BETWEEN 0 AND 1
        OR v_NguongNguoi <> FLOOR(v_NguongNguoi) OR v_BuocNguoi <> FLOOR(v_BuocNguoi) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Thieu hoac sai tham so bac thang.', MYSQL_ERRNO = 51305;
    END IF;

    /* Kiem tra du lieu nguon chong lich; khong de double-count khi trigger chua co. */
    IF EXISTS (SELECT 1 FROM HopDongThue a JOIN HopDongThue b
        ON a.MaVanPhong = b.MaVanPhong AND a.MaHopDong < b.MaHopDong
        JOIN VanPhong v ON v.MaVanPhong = a.MaVanPhong
        WHERE v.MaToaNha = p_MaToaNha AND a.NgayBatDau <= v_Den AND b.NgayBatDau <= v_Den
            AND COALESCE(a.NgayKetThuc, DATE '9999-12-31') >= v_Tu
            AND COALESCE(b.NgayKetThuc, DATE '9999-12-31') >= v_Tu
            AND a.NgayBatDau <= COALESCE(b.NgayKetThuc, DATE '9999-12-31')
            AND b.NgayBatDau <= COALESCE(a.NgayKetThuc, DATE '9999-12-31')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Du lieu nguon co hop dong chong lich.', MYSQL_ERRNO = 51306;
    END IF;

    INSERT INTO tmp_TV4_Ngay (Ngay)
    WITH RECURSIVE n AS (
        SELECT v_Tu AS Ngay UNION ALL SELECT DATE_ADD(Ngay, INTERVAL 1 DAY) FROM n WHERE Ngay < v_Den
    )
    SELECT Ngay FROM n;

    /* Tien thue: moi ngay thuoc hop dong duoc tinh ca ngay dau va ngay cuoi. */
    INSERT INTO tmp_TV4_Dong (MaCongTy, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
    SELECT h.MaCongTy, 'THUE_VAN_PHONG', v.MaVanPhong, NULL, v.DienTich, t.DonGiaThueM2,
        CAST(COUNT(*) * 1.0 / DAY(v_Den) AS DECIMAL(12,10))
    FROM HopDongThue h
    JOIN VanPhong v ON v.MaVanPhong = h.MaVanPhong
    JOIN ViTri t ON t.MaViTri = v.MaViTri
    JOIN tmp_TV4_Ngay n ON h.NgayBatDau <= n.Ngay
        AND COALESCE(h.NgayKetThuc, DATE '9999-12-31') >= n.Ngay
    WHERE v.MaToaNha = p_MaToaNha
    GROUP BY h.MaCongTy, v.MaVanPhong, v.DienTich, t.DonGiaThueM2;

    /* So nguoi tinh tren cong ty; dien tich tinh rieng toa nha, theo tung ngay.
       Theo seed TV3: <=10 nguoi = 0 bac, (10,15] = 1 bac, (15,20] = 2 bac.
       Dien tich <=100 = 0 bac; (100,110] = 1 bac; (110,120] = 2 bac.
       Cong don bac nguoi va dien tich; khong lay MAX hai bac. */
    CREATE TEMPORARY TABLE tmp_TV4_PhiRaw AS
    SELECT sd.MaCongTy, sd.MaDichVu, sd.Ngay, d.DonGiaCoBan, l.CoTinhTheoNguoi, l.CoTinhTheoDienTich,
        (SELECT COUNT(*) FROM NhanVienCongTy nv
            WHERE nv.MaCongTy = sd.MaCongTy AND nv.NgayVaoLam <= sd.Ngay
                AND COALESCE(nv.NgayNghiViec, DATE '9999-12-31') >= sd.Ngay) AS SoNguoi,
        (SELECT CAST(SUM(v.DienTich) AS DECIMAL(18,2)) FROM HopDongThue h
            JOIN VanPhong v ON v.MaVanPhong = h.MaVanPhong
            WHERE h.MaCongTy = sd.MaCongTy AND v.MaToaNha = p_MaToaNha AND h.NgayBatDau <= sd.Ngay
                AND COALESCE(h.NgayKetThuc, DATE '9999-12-31') >= sd.Ngay) AS DienTich
    FROM (
        SELECT DISTINCT s.MaCongTy, s.MaDichVu, n.Ngay
        FROM SuDungDichVu s
        JOIN DichVu d ON d.MaDichVu = s.MaDichVu
        JOIN LoaiDichVu l ON l.MaLoaiDV = d.MaLoaiDV
        JOIN tmp_TV4_Ngay n ON s.NgayBatDau <= n.Ngay
            AND COALESCE(s.NgayKetThuc, DATE '9999-12-31') >= n.Ngay
        WHERE d.MaToaNha = p_MaToaNha AND l.KieuTinhPhi = 'THANG'
    ) AS sd
    JOIN DichVu d ON d.MaDichVu = sd.MaDichVu
    JOIN LoaiDichVu l ON l.MaLoaiDV = d.MaLoaiDV;

    IF EXISTS (SELECT 1 FROM tmp_TV4_PhiRaw WHERE DienTich IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dang ky dich vu thang co ngay khong co hop dong thue cung toa.', MYSQL_ERRNO = 51307;
    END IF;

    CREATE TEMPORARY TABLE tmp_TV4_Phi AS
    SELECT r.MaCongTy, r.MaDichVu, r.Ngay,
        CAST(ROUND(CAST(r.DonGiaCoBan AS DECIMAL(18,2)) * CAST(1 + v_TyLe * CAST((
            CASE WHEN r.CoTinhTheoNguoi = 1 AND r.SoNguoi > v_NguongNguoi
                THEN CEILING((r.SoNguoi - v_NguongNguoi) / v_BuocNguoi) ELSE 0 END
            + CASE WHEN r.CoTinhTheoDienTich = 1 AND r.DienTich > v_NguongDT
                THEN CEILING((r.DienTich - v_NguongDT) / v_BuocDT) ELSE 0 END) AS DECIMAL(18,2))
            AS DECIMAL(18,6)), 2) AS DECIMAL(18,2)) AS DonGia,
        r.DienTich
    FROM tmp_TV4_PhiRaw r;

    INSERT INTO tmp_TV4_Dong (MaCongTy, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
    SELECT MaCongTy, 'DICH_VU_THANG', NULL, MaDichVu, 1, DonGia,
        CAST(COUNT(*) * 1.0 / DAY(v_Den) AS DECIMAL(12,10))
    FROM tmp_TV4_Phi
    GROUP BY MaCongTy, MaDichVu, DonGia;

    /* Nhom theo don gia lich su; khong lay gia hien tai de tinh lai nhat ky. */
    INSERT INTO tmp_TV4_Dong (MaCongTy, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
    SELECT nv.MaCongTy, 'DICH_VU_LUOT', NULL, c.MaDichVu, SUM(c.SoLuot), c.DonGiaApDung, 1
    FROM ChiTietSuDungNV c
    JOIN NhanVienCongTy nv ON nv.MaNVCT = c.MaNVCT
    JOIN DichVu d ON d.MaDichVu = c.MaDichVu
    WHERE d.MaToaNha = p_MaToaNha AND c.NgaySuDung BETWEEN v_Tu AND v_Den
    GROUP BY nv.MaCongTy, c.MaDichVu, c.DonGiaApDung;

    IF NOT EXISTS (SELECT 1 FROM tmp_TV4_Dong) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ky khong co khoan thu de lap hoa don.', MYSQL_ERRNO = 51308;
    END IF;

    INSERT INTO HoaDonThang (MaCongTy, MaToaNha, Thang, Nam, NgayLap)
    SELECT DISTINCT MaCongTy, p_MaToaNha, p_Thang, p_Nam, CURDATE() FROM tmp_TV4_Dong;

    INSERT INTO ChiTietHoaDon (MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
    SELECT h.MaHoaDon, d.LoaiKhoan, d.MaVanPhong, d.MaDichVu, d.SoLuong, d.DonGiaApDung, d.TyLeNgay
    FROM tmp_TV4_Dong d
    JOIN HoaDonThang h ON h.MaCongTy = d.MaCongTy AND h.MaToaNha = p_MaToaNha
        AND h.Thang = p_Thang AND h.Nam = p_Nam;

    COMMIT;
    DO RELEASE_LOCK('TV4_NghiepVu');
    SELECT h.MaHoaDon, h.MaCongTy, CAST(SUM(c.SoTien) AS DECIMAL(18,2)) AS TongTien
    FROM HoaDonThang h
    JOIN V_ChiTietHoaDon c ON c.MaHoaDon = h.MaHoaDon
    WHERE h.MaToaNha = p_MaToaNha AND h.Thang = p_Thang AND h.Nam = p_Nam
    GROUP BY h.MaHoaDon, h.MaCongTy
    ORDER BY h.MaHoaDon;

    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_Phi;
    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_PhiRaw;
    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_Dong;
    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_Ngay;
END$$

/* ----------------------------------------------------------------------------
   T4: Thanh toan du mot lan cho hoa don (ghi thang tren HoaDonThang, khong co so quy rieng)
   ---------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS USP_Trx_ThanhToanHoaDonVaVaoSoQuy$$
CREATE PROCEDURE USP_Trx_ThanhToanHoaDonVaVaoSoQuy(
    IN p_MaHoaDon INT, IN p_SoTien DECIMAL(18,2), IN p_NgayThanhToan DATE, IN p_NguoiThu VARCHAR(100))
BEGIN
    DECLARE v_Khoa INT;
    DECLARE v_TrangThai VARCHAR(20);
    DECLARE v_NgayLap DATE;
    DECLARE v_Tong DECIMAL(18,2);
    DECLARE v_NguoiThu VARCHAR(100);
    DECLARE v_SoDong INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DO RELEASE_LOCK('TV4_NghiepVu');
        RESIGNAL;
    END;

    SET v_Khoa = GET_LOCK('TV4_NghiepVu', 10);
    IF v_Khoa IS NULL OR v_Khoa <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong lay duoc khoa nghiep vu. Thu lai sau.', MYSQL_ERRNO = 51001;
    END IF;

    IF p_MaHoaDon IS NULL OR p_SoTien IS NULL OR p_SoTien <= 0 OR p_NgayThanhToan IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ma hoa don, so tien va ngay thanh toan phai hop le va khac NULL.', MYSQL_ERRNO = 51401;
    END IF;
    IF p_NguoiThu IS NOT NULL AND CHAR_LENGTH(TRIM(p_NguoiThu)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ten nguoi thu khong duoc la chuoi rong hoac toan dau cach.', MYSQL_ERRNO = 51404;
    END IF;
    SET v_NguoiThu = CASE WHEN p_NguoiThu IS NULL THEN NULL ELSE TRIM(p_NguoiThu) END;

    START TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM HoaDonThang WHERE MaHoaDon = p_MaHoaDon) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hoa don khong ton tai.', MYSQL_ERRNO = 51402;
    END IF;
    SELECT TrangThai, NgayLap INTO v_TrangThai, v_NgayLap
    FROM HoaDonThang WHERE MaHoaDon = p_MaHoaDon FOR UPDATE;

    IF v_TrangThai = 'DA_THANH_TOAN' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hoa don da duoc thanh toan truoc do.', MYSQL_ERRNO = 51403;
    END IF;
    IF p_NgayThanhToan < v_NgayLap OR p_NgayThanhToan > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ngay thanh toan phai tu NgayLap den hien tai.', MYSQL_ERRNO = 51405;
    END IF;

    SELECT SUM(c.SoTien) INTO v_Tong FROM V_ChiTietHoaDon c WHERE c.MaHoaDon = p_MaHoaDon;
    IF v_Tong IS NULL OR v_Tong <= 0 OR p_SoTien <> v_Tong THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'So tien thanh toan khong khop tong tien hoa don (chi ho tro tra du 1 lan).', MYSQL_ERRNO = 51406;
    END IF;

    UPDATE HoaDonThang
    SET TrangThai = 'DA_THANH_TOAN', NgayThanhToan = p_NgayThanhToan, NguoiThu = v_NguoiThu
    WHERE MaHoaDon = p_MaHoaDon AND TrangThai = 'CHUA_THANH_TOAN';
    SET v_SoDong = ROW_COUNT();
    IF v_SoDong <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong cap nhat duoc trang thai thanh toan.', MYSQL_ERRNO = 51407;
    END IF;

    COMMIT;
    DO RELEASE_LOCK('TV4_NghiepVu');
    SELECT h.MaHoaDon, h.MaCongTy, h.MaToaNha, h.Thang, h.Nam,
        h.TrangThai, h.NgayThanhToan, h.NguoiThu, v_Tong AS SoTienDaThu
    FROM HoaDonThang h
    WHERE h.MaHoaDon = p_MaHoaDon;
END$$

/* ----------------------------------------------------------------------------
   T5: Chot bang luong nhan vien toa nha (sau khi da lap hoa don cua ky)
   ---------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS USP_Trx_ChotBangLuongNhanVien$$
CREATE PROCEDURE USP_Trx_ChotBangLuongNhanVien(IN p_MaToaNha VARCHAR(20), IN p_Thang TINYINT, IN p_Nam SMALLINT)
BEGIN
    DECLARE v_Khoa INT;
    DECLARE v_TuKy DATE;
    DECLARE v_DenKy DATE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DO RELEASE_LOCK('TV4_NghiepVu');
        RESIGNAL;
    END;

    SET v_Khoa = GET_LOCK('TV4_NghiepVu', 10);
    IF v_Khoa IS NULL OR v_Khoa <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong lay duoc khoa nghiep vu. Thu lai sau.', MYSQL_ERRNO = 51001;
    END IF;

    IF p_Thang IS NULL OR p_Thang NOT BETWEEN 1 AND 12 OR p_Nam IS NULL OR p_Nam NOT BETWEEN 1900 AND 9999 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Thang hoac nam khong hop le.', MYSQL_ERRNO = 51501;
    END IF;
    SET v_TuKy = MAKEDATE(p_Nam, 1) + INTERVAL (p_Thang - 1) MONTH;
    SET v_DenKy = LAST_DAY(v_TuKy);

    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_NhanVien;

    START TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM HoaDonThang WHERE MaToaNha = p_MaToaNha AND Thang = p_Thang AND Nam = p_Nam FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Phai chot hoa don cua toa nha truoc khi tinh luong.', MYSQL_ERRNO = 51502;
    END IF;
    IF EXISTS (
        SELECT 1 FROM (
            SELECT h.MaCongTy FROM HopDongThue h JOIN VanPhong v ON v.MaVanPhong = h.MaVanPhong
            WHERE v.MaToaNha = p_MaToaNha AND h.NgayBatDau <= v_DenKy
                AND COALESCE(h.NgayKetThuc, DATE '9999-12-31') >= v_TuKy
            UNION
            SELECT s.MaCongTy FROM SuDungDichVu s JOIN DichVu d ON d.MaDichVu = s.MaDichVu
            WHERE d.MaToaNha = p_MaToaNha AND s.NgayBatDau <= v_DenKy
                AND COALESCE(s.NgayKetThuc, DATE '9999-12-31') >= v_TuKy
        ) AS c
        WHERE NOT EXISTS (SELECT 1 FROM HoaDonThang h WHERE h.MaCongTy = c.MaCongTy
            AND h.MaToaNha = p_MaToaNha AND h.Thang = p_Thang AND h.Nam = p_Nam)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Con cong ty chua duoc lap hoa don trong ky.', MYSQL_ERRNO = 51509;
    END IF;
    IF EXISTS (SELECT 1 FROM LuongThang l JOIN NhanVienToaNha n ON n.MaNVTN = l.MaNVTN
        WHERE n.MaToaNha = p_MaToaNha AND l.Thang = p_Thang AND l.Nam = p_Nam) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ky da co luong. Khong tinh lai hoac ghi de.', MYSQL_ERRNO = 51503;
    END IF;
    IF EXISTS (SELECT 1 FROM NhanVienToaNha n WHERE n.MaToaNha = p_MaToaNha AND n.NgayVaoLam <= v_DenKy
        AND NOT EXISTS (SELECT 1 FROM PhanCongNVTN p
            WHERE p.MaNVTN = n.MaNVTN AND p.Thang = p_Thang AND p.Nam = p_Nam)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Co nhan vien chua duoc phan cong trong thang.', MYSQL_ERRNO = 51505;
    END IF;
    IF EXISTS (SELECT 1 FROM PhanCongNVTN p JOIN NhanVienToaNha n ON n.MaNVTN = p.MaNVTN
        LEFT JOIN DichVu d ON d.MaDichVu = p.MaDichVu
        LEFT JOIN BacCongViec b ON b.MaBac = p.MaBac
        WHERE n.MaToaNha = p_MaToaNha AND p.Thang = p_Thang AND p.Nam = p_Nam
        AND (n.NgayVaoLam > v_DenKy OR b.MaBac IS NULL OR b.HeSoDoanhThu NOT BETWEEN 0 AND 1 OR b.LuongCoBan <= 0
            OR (n.LoaiNV = 'QUAN_LY' AND p.MaDichVu IS NOT NULL)
            OR (n.LoaiNV = 'DICH_VU' AND (d.MaDichVu IS NULL OR d.MaToaNha <> p_MaToaNha))
            OR n.LoaiNV NOT IN ('QUAN_LY', 'DICH_VU'))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Phan cong, bac luong hoac dich vu khong hop le.', MYSQL_ERRNO = 51506;
    END IF;
    IF (SELECT COUNT(*) FROM NhanVienToaNha WHERE MaToaNha = p_MaToaNha
        AND LoaiNV = 'QUAN_LY' AND NgayVaoLam <= v_DenKy) <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Toa nha phai co dung mot quan ly trong thang.', MYSQL_ERRNO = 51507;
    END IF;

    /* TV3: HeSoDoanhThu la TY LE RIENG tung nhan vien, khong phai trong so.
       Quan ly khong gan MaDichVu nen doanh thu 0, thuong 0 nhu seed.
       Dich vu THANG va LUOT deu lay doanh thu tu chi tiet hoa don da chot. */
    CREATE TEMPORARY TABLE tmp_TV4_NhanVien AS
    SELECT n.MaNVTN, b.LuongCoBan,
        CAST(ROUND(CAST(COALESCE((
            SELECT SUM(c.SoTien) FROM HoaDonThang h JOIN V_ChiTietHoaDon c ON c.MaHoaDon = h.MaHoaDon
            WHERE h.MaToaNha = p_MaToaNha AND h.Thang = p_Thang AND h.Nam = p_Nam
                AND c.MaDichVu = p.MaDichVu AND c.LoaiKhoan IN ('DICH_VU_THANG', 'DICH_VU_LUOT')
        ), 0) AS DECIMAL(28,2)) * b.HeSoDoanhThu, 2) AS DECIMAL(18,2)) AS TienThuong
    FROM PhanCongNVTN p
    JOIN NhanVienToaNha n ON n.MaNVTN = p.MaNVTN
    JOIN BacCongViec b ON b.MaBac = p.MaBac
    WHERE n.MaToaNha = p_MaToaNha AND p.Thang = p_Thang AND p.Nam = p_Nam;

    IF NOT EXISTS (SELECT 1 FROM tmp_TV4_NhanVien) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong co nhan vien de tinh luong.', MYSQL_ERRNO = 51508;
    END IF;

    INSERT INTO LuongThang (MaNVTN, Thang, Nam, LuongCoBan, TienThuong)
    SELECT MaNVTN, p_Thang, p_Nam, LuongCoBan, TienThuong FROM tmp_TV4_NhanVien;

    COMMIT;
    DO RELEASE_LOCK('TV4_NghiepVu');
    SELECT l.MaNVTN, l.Thang, l.Nam, l.LuongCoBan, l.TienThuong, l.LuongCoBan + l.TienThuong AS TongLuong
    FROM LuongThang l
    JOIN tmp_TV4_NhanVien n ON n.MaNVTN = l.MaNVTN
    WHERE l.Thang = p_Thang AND l.Nam = p_Nam;

    DROP TEMPORARY TABLE IF EXISTS tmp_TV4_NhanVien;
END$$

DELIMITER ;

SELECT 'TV4: da cai 5 stored procedure giao dich (MySQL)' AS KetQua;
