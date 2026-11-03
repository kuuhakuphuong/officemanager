/* ============================================================================
   TV3 - Du lieu mau 2 thang (08-09/2026) cho MySQL 8.0
   Chay sau 01_CreateSchema. Toan bo seed nam trong mot transaction:
   neu kiem tra cuoi sai so luong thi ROLLBACK, giong ban SQL Server.
   ============================================================================ */
USE QLToaNha_BCNF;

DROP PROCEDURE IF EXISTS usp_TV3_NapDuLieuMau;

DELIMITER $$
CREATE PROCEDURE usp_TV3_NapDuLieuMau()
BEGIN
    DECLARE v_SoDong INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Chi nap khi 18 bang rong; khong xoa du lieu cu.
    SELECT (SELECT COUNT(*) FROM ThamSo) + (SELECT COUNT(*) FROM ViTri) + (SELECT COUNT(*) FROM LoaiDichVu)
        + (SELECT COUNT(*) FROM BacCongViec) + (SELECT COUNT(*) FROM ToaNha) + (SELECT COUNT(*) FROM CongTy)
        + (SELECT COUNT(*) FROM VanPhong) + (SELECT COUNT(*) FROM NhanVienCongTy) + (SELECT COUNT(*) FROM DichVu)
        + (SELECT COUNT(*) FROM NhanVienToaNha) + (SELECT COUNT(*) FROM HoaDonThang)
        + (SELECT COUNT(*) FROM ChiPhiVanHanh) + (SELECT COUNT(*) FROM HopDongThue)
        + (SELECT COUNT(*) FROM SuDungDichVu) + (SELECT COUNT(*) FROM ChiTietSuDungNV)
        + (SELECT COUNT(*) FROM PhanCongNVTN) + (SELECT COUNT(*) FROM ChiTietHoaDon)
        + (SELECT COUNT(*) FROM LuongThang) INTO v_SoDong;
    IF v_SoDong > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Database da co du lieu. Seed chi chay tren 18 bang rong; khong xoa du lieu cu.', MYSQL_ERRNO = 51002;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_So;
    DROP TEMPORARY TABLE IF EXISTS tmp_Ngay;
    DROP TEMPORARY TABLE IF EXISTS tmp_Ky;
    CREATE TEMPORARY TABLE tmp_So (So INT NOT NULL PRIMARY KEY);
    CREATE TEMPORARY TABLE tmp_Ngay (Ngay DATE NOT NULL PRIMARY KEY);
    CREATE TEMPORARY TABLE tmp_Ky (Thang TINYINT NOT NULL, Nam SMALLINT NOT NULL, NgayDau DATE NOT NULL PRIMARY KEY);

    START TRANSACTION;

    INSERT INTO tmp_So(So)
    WITH RECURSIVE n AS (SELECT 0 AS So UNION ALL SELECT So + 1 FROM n WHERE So < 99)
    SELECT So FROM n;

    INSERT INTO tmp_Ngay(Ngay)
    WITH RECURSIVE n AS (SELECT DATE '2026-08-01' AS Ngay UNION ALL SELECT DATE_ADD(Ngay, INTERVAL 1 DAY) FROM n WHERE Ngay < DATE '2026-09-30')
    SELECT Ngay FROM n;

    INSERT INTO tmp_Ky(Thang, Nam, NgayDau) VALUES (8, 2026, '2026-08-01'), (9, 2026, '2026-09-01');

    INSERT INTO ThamSo(TenThamSo, GiaTri, MoTa) VALUES
        ('NGUONG_NGUOI', 10, 'Nguong so nguoi duong; gia dinh cho du lieu mau'),
        ('BUOC_NGUOI', 5, 'Buoc tang so nguoi; gia dinh cho du lieu mau'),
        ('NGUONG_DIEN_TICH', 100, 'Nguong dien tich m2; gia dinh cho du lieu mau'),
        ('BUOC_DIEN_TICH', 10, 'Buoc tang dien tich m2; gia dinh cho du lieu mau'),
        ('TY_LE_TANG_GIA', 0.05, 'Ty le tang phi; gia dinh cho du lieu mau');

    INSERT INTO ViTri(MaViTri, TenViTri, DonGiaThueM2) VALUES
        ('VT_TRONG', 'Khu vực trong nhà', 200000),
        ('VT_MAT_TIEN', 'Mặt tiền', 250000);

    INSERT INTO LoaiDichVu(MaLoaiDV, TenLoai, KieuTinhPhi, CoTinhTheoNguoi, CoTinhTheoDienTich) VALUES
        ('AN_UONG', 'Ăn uống', 'LUOT', 0, 0),
        ('GUI_XE', 'Gửi xe', 'LUOT', 0, 0),
        ('VE_SINH', 'Vệ sinh văn phòng', 'THANG', 1, 1);

    INSERT INTO BacCongViec(MaBac, TenBac, LuongCoBan, HeSoDoanhThu) VALUES
        ('BAC_QL', 'Quản lý tòa nhà', 18000000, 0),
        ('BAC_AN', 'Nhân viên nhà ăn', 8000000, 0.05),
        ('BAC_XE', 'Nhân viên bãi xe', 7500000, 0.04);

    INSERT INTO ToaNha(MaToaNha, TenToaNha, DiaChi, SoTang) VALUES
        ('TN01', 'Tòa nhà Thăng Long Center', 'Số 10 Duy Tân, Cầu Giấy, Hà Nội', 9),
        ('TN02', 'Tòa nhà Sông Hàn Business', 'Số 120 Bạch Đằng, Hải Châu, Đà Nẵng', 10),
        ('TN03', 'Tòa nhà Sài Gòn Tower', 'Số 25 Lê Duẩn, Quận 1, TP. Hồ Chí Minh', 11);

    INSERT INTO CongTy(MaCongTy, TenCongTy, MaSoThue, DiaChi, DienThoai, Email, LinhVuc) VALUES
        ('CT01', 'Công ty TNHH Giải pháp Phần mềm Thăng Long', '0101234501', 'Số 5 Phạm Hùng, Nam Từ Liêm, Hà Nội', '0243123401', 'contact@thanglongsoft.vn', 'Công nghệ thông tin'),
        ('CT02', 'Công ty Cổ phần Thương mại Hoàng Hà', '0101234502', 'Số 18 Nguyễn Chí Thanh, Đống Đa, Hà Nội', '0243123402', 'info@hoanghatrade.vn', 'Thương mại'),
        ('CT03', 'Công ty TNHH Tư vấn Tài chính Bình Minh', '0101234503', 'Số 9 Láng Hạ, Ba Đình, Hà Nội', '0243123403', 'hello@binhminhfin.vn', 'Tài chính'),
        ('CT04', 'Công ty Cổ phần Logistics Sông Hồng', '0101234504', 'Số 33 Trần Phú, Hà Đông, Hà Nội', '0243123404', 'sales@songhonglogistics.vn', 'Logistics'),
        ('CT05', 'Công ty TNHH Dược phẩm An Khang', '0101234505', 'Số 71 Hoàng Quốc Việt, Cầu Giấy, Hà Nội', '0243123405', 'cskh@ankhangpharma.vn', 'Dược phẩm'),
        ('CT06', 'Công ty Cổ phần Đầu tư Sao Mai', '0101234506', 'Số 2 Cầu Giấy, Ba Đình, Hà Nội', '0243123406', 'contact@saomai-invest.vn', 'Bất động sản');

    INSERT INTO VanPhong(MaVanPhong, MaToaNha, MaViTri, Tang, DienTich)
    SELECT CONCAT('VP', RIGHT(CONCAT('00', So), 2)), CONCAT('TN0', (So - 1) DIV 4 + 1),
        CASE WHEN So % 2 = 0 THEN 'VT_MAT_TIEN' ELSE 'VT_TRONG' END,
        (So - 1) % 4 + 1, CASE WHEN So % 2 = 0 THEN 120 ELSE 80 END
    FROM tmp_So WHERE So BETWEEN 1 AND 12;

    INSERT INTO HopDongThue(MaHopDong, MaCongTy, MaVanPhong, NgayBatDau, NgayKetThuc)
    SELECT CONCAT('HD', RIGHT(CONCAT('00', So), 2)), CONCAT('CT0', (So - 1) DIV 2 + 1),
        CONCAT('VP', RIGHT(CONCAT('00', So), 2)), '2026-07-01', '2027-06-30'
    FROM tmp_So WHERE So BETWEEN 1 AND 12;

    INSERT INTO NhanVienCongTy(MaNVCT, MaCongTy, HoTen, GioiTinh, NgaySinh,
        DienThoai, Email, ChucVu, NgayVaoLam, NgayNghiViec)
    SELECT CONCAT('NVCT', RIGHT(CONCAT('000', So), 3)), CONCAT('CT0', (So - 1) DIV 10 + 1),
        -- Ho ten ghep tu ho, dem, ten theo gioi tinh (dong nhat voi ma So nen khong trung lap nhieu).
        CONCAT(
            ELT(MOD(So, 8) + 1, 'Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Vũ', 'Đặng', 'Bùi'), ' ',
            CASE WHEN So % 2 = 0 THEN ELT(MOD(So, 5) + 1, 'Thị', 'Ngọc', 'Thu', 'Kim', 'Phương')
                ELSE ELT(MOD(So, 5) + 1, 'Văn', 'Đức', 'Quốc', 'Minh', 'Hữu') END, ' ',
            CASE WHEN So % 2 = 0 THEN ELT(MOD(So * 3, 10) + 1, 'Lan', 'Hoa', 'Mai', 'Linh', 'Hương', 'Trang', 'Nga', 'Thảo', 'Yến', 'Ngân')
                ELSE ELT(MOD(So * 3, 10) + 1, 'Anh', 'Hùng', 'Dũng', 'Khoa', 'Long', 'Tuấn', 'Nam', 'Sơn', 'Đạt', 'Hiếu') END),
        CASE WHEN So % 2 = 0 THEN 'F' ELSE 'M' END,
        DATE_ADD(DATE '1990-01-01', INTERVAL So * 17 DAY),
        CONCAT('09100000', RIGHT(CONCAT('00', So), 2)), CONCAT('employee', So, '@example.com'),
        ELT(MOD(So, 3) + 1, 'Chuyên viên', 'Nhân viên kinh doanh', 'Kế toán viên'), '2026-07-01', NULL
    FROM tmp_So WHERE So BETWEEN 1 AND 60;

    INSERT INTO DichVu(MaDichVu, MaToaNha, MaLoaiDV, TenDichVu, DonGiaCoBan)
    SELECT CONCAT(loai.TienTo, RIGHT(toanha.MaToaNha, 2)), toanha.MaToaNha,
        loai.MaLoaiDV, CONCAT(loai.Ten, ' - ', toanha.TenToaNha), loai.DonGia
    FROM ToaNha AS toanha
    CROSS JOIN (
        SELECT 'AN' AS TienTo, 'AN_UONG' AS MaLoaiDV, 'Bữa trưa' AS Ten, CAST(35000 AS DECIMAL(18,2)) AS DonGia
        UNION ALL SELECT 'XE', 'GUI_XE', 'Gửi xe máy', CAST(5000 AS DECIMAL(18,2))
        UNION ALL SELECT 'VS', 'VE_SINH', 'Vệ sinh', CAST(1500000 AS DECIMAL(18,2))
    ) AS loai;

    INSERT INTO SuDungDichVu(MaCongTy, MaDichVu, NgayBatDau, NgayKetThuc)
    SELECT DISTINCT hd.MaCongTy, dv.MaDichVu, '2026-07-01', '2027-06-30'
    FROM HopDongThue AS hd
    JOIN VanPhong AS vp ON vp.MaVanPhong = hd.MaVanPhong
    JOIN DichVu AS dv ON dv.MaToaNha = vp.MaToaNha;

    INSERT INTO ChiTietSuDungNV(MaNVCT, MaDichVu, NgaySuDung, SoLuot, DonGiaApDung)
    SELECT nv.MaNVCT, dv.MaDichVu, ngay.Ngay, 1, dv.DonGiaCoBan
    FROM NhanVienCongTy AS nv
    JOIN SuDungDichVu AS dk ON dk.MaCongTy = nv.MaCongTy
    JOIN DichVu AS dv ON dv.MaDichVu = dk.MaDichVu
    JOIN LoaiDichVu AS loai ON loai.MaLoaiDV = dv.MaLoaiDV AND loai.KieuTinhPhi = 'LUOT'
    CROSS JOIN tmp_Ngay AS ngay;

    INSERT INTO NhanVienToaNha(MaNVTN, MaToaNha, MaQuanLy, LoaiNV, HoTen,
        GioiTinh, NgaySinh, DienThoai, Email, NgayVaoLam) VALUES
        ('QL01', 'TN01', NULL, 'QUAN_LY', 'Nguyễn Hoàng Long', 'M', '1985-01-01', '0912000001', 'quanly.thanglong@example.com', '2026-01-01'),
        ('QL02', 'TN02', NULL, 'QUAN_LY', 'Phạm Đức Thắng', 'M', '1983-05-14', '0912000002', 'quanly.songhan@example.com', '2026-01-01'),
        ('QL03', 'TN03', NULL, 'QUAN_LY', 'Lê Thị Ngọc Anh', 'F', '1987-09-02', '0912000003', 'quanly.saigon@example.com', '2026-01-01');

    INSERT INTO NhanVienToaNha(MaNVTN, MaToaNha, MaQuanLy, LoaiNV, HoTen,
        GioiTinh, NgaySinh, DienThoai, Email, NgayVaoLam) VALUES
        ('NVAN01', 'TN01', 'QL01', 'DICH_VU', 'Hoàng Thị Lan', 'F', '1992-01-01', NULL, 'lan.hoang@example.com', '2026-01-01'),
        ('NVXE01', 'TN01', 'QL01', 'DICH_VU', 'Vũ Minh Khoa', 'M', '1992-01-01', NULL, 'khoa.vu@example.com', '2026-01-01'),
        ('NVAN02', 'TN02', 'QL02', 'DICH_VU', 'Đặng Thị Thu Hiền', 'F', '1992-01-01', NULL, 'hien.dang@example.com', '2026-01-01'),
        ('NVXE02', 'TN02', 'QL02', 'DICH_VU', 'Bùi Quốc Bảo', 'M', '1992-01-01', NULL, 'bao.bui@example.com', '2026-01-01'),
        ('NVAN03', 'TN03', 'QL03', 'DICH_VU', 'Trần Thị Ngọc Yến', 'F', '1992-01-01', NULL, 'yen.tran@example.com', '2026-01-01'),
        ('NVXE03', 'TN03', 'QL03', 'DICH_VU', 'Nguyễn Văn Tâm', 'M', '1992-01-01', NULL, 'tam.nguyen@example.com', '2026-01-01');

    INSERT INTO PhanCongNVTN(MaNVTN, Thang, Nam, MaDichVu, MaBac)
    SELECT nv.MaNVTN, ky.Thang, ky.Nam, dv.MaDichVu,
        CASE WHEN nv.LoaiNV = 'QUAN_LY' THEN 'BAC_QL'
            WHEN dv.MaLoaiDV = 'AN_UONG' THEN 'BAC_AN' ELSE 'BAC_XE' END
    FROM NhanVienToaNha AS nv
    LEFT JOIN DichVu AS dv ON nv.MaNVTN = CONCAT('NV', dv.MaDichVu)
    CROSS JOIN tmp_Ky AS ky;

    INSERT INTO LuongThang(MaNVTN, Thang, Nam, LuongCoBan, TienThuong)
    SELECT pc.MaNVTN, pc.Thang, pc.Nam, bac.LuongCoBan,
        CAST(COALESCE((
            SELECT SUM(CAST(logdv.SoLuot AS DECIMAL(18,2)) * logdv.DonGiaApDung)
            FROM ChiTietSuDungNV AS logdv
            WHERE logdv.MaDichVu = pc.MaDichVu
                AND logdv.NgaySuDung >= MAKEDATE(pc.Nam, 1) + INTERVAL (pc.Thang - 1) MONTH
                AND logdv.NgaySuDung < MAKEDATE(pc.Nam, 1) + INTERVAL pc.Thang MONTH
        ), 0) * bac.HeSoDoanhThu AS DECIMAL(18,2))
    FROM PhanCongNVTN AS pc
    JOIN BacCongViec AS bac ON bac.MaBac = pc.MaBac;

    INSERT INTO HoaDonThang(MaCongTy, MaToaNha, Thang, Nam, NgayLap)
    SELECT DISTINCT hd.MaCongTy, vp.MaToaNha, ky.Thang, ky.Nam, LAST_DAY(ky.NgayDau)
    FROM HopDongThue AS hd
    JOIN VanPhong AS vp ON vp.MaVanPhong = hd.MaVanPhong
    CROSS JOIN tmp_Ky AS ky;

    UPDATE HoaDonThang
    SET TrangThai = 'DA_THANH_TOAN', NgayThanhToan = DATE_ADD(NgayLap, INTERVAL 5 DAY),
        NguoiThu = 'Nguyễn Thị Thu Hà'
    WHERE Thang = 8;

    INSERT INTO ChiTietHoaDon(MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
    SELECT hoadon.MaHoaDon, 'THUE_VAN_PHONG', vp.MaVanPhong, NULL,
        vp.DienTich, vitri.DonGiaThueM2, 1
    FROM HoaDonThang AS hoadon
    JOIN HopDongThue AS hd ON hd.MaCongTy = hoadon.MaCongTy
    JOIN VanPhong AS vp ON vp.MaVanPhong = hd.MaVanPhong AND vp.MaToaNha = hoadon.MaToaNha
    JOIN ViTri AS vitri ON vitri.MaViTri = vp.MaViTri;

    INSERT INTO ChiTietHoaDon(MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
    WITH CauHinh AS (
        SELECT
            MAX(CASE WHEN TenThamSo = 'NGUONG_NGUOI' THEN GiaTri END) AS NguongNguoi,
            MAX(CASE WHEN TenThamSo = 'BUOC_NGUOI' THEN GiaTri END) AS BuocNguoi,
            MAX(CASE WHEN TenThamSo = 'NGUONG_DIEN_TICH' THEN GiaTri END) AS NguongDienTich,
            MAX(CASE WHEN TenThamSo = 'BUOC_DIEN_TICH' THEN GiaTri END) AS BuocDienTich,
            MAX(CASE WHEN TenThamSo = 'TY_LE_TANG_GIA' THEN GiaTri END) AS TyLe
        FROM ThamSo
    ), MatBang AS (
        SELECT hd.MaCongTy, vp.MaToaNha, SUM(vp.DienTich) AS DienTich
        FROM HopDongThue AS hd
        JOIN VanPhong AS vp ON vp.MaVanPhong = hd.MaVanPhong
        GROUP BY hd.MaCongTy, vp.MaToaNha
    ), NhanSu AS (
        SELECT MaCongTy, COUNT(*) AS SoNguoi FROM NhanVienCongTy GROUP BY MaCongTy
    )
    SELECT hoadon.MaHoaDon, 'DICH_VU_THANG', NULL, dv.MaDichVu, 1,
        dv.DonGiaCoBan * (1 + cauhinh.TyLe * (
            CASE WHEN loai.CoTinhTheoNguoi = 1 AND nhansu.SoNguoi > cauhinh.NguongNguoi
                THEN CEILING((nhansu.SoNguoi - cauhinh.NguongNguoi) / cauhinh.BuocNguoi) ELSE 0 END
            + CASE WHEN loai.CoTinhTheoDienTich = 1 AND matbang.DienTich > cauhinh.NguongDienTich
                THEN CEILING((matbang.DienTich - cauhinh.NguongDienTich) / cauhinh.BuocDienTich) ELSE 0 END)), 1
    FROM HoaDonThang AS hoadon
    JOIN SuDungDichVu AS dk ON dk.MaCongTy = hoadon.MaCongTy
    JOIN DichVu AS dv ON dv.MaDichVu = dk.MaDichVu AND dv.MaToaNha = hoadon.MaToaNha
    JOIN LoaiDichVu AS loai ON loai.MaLoaiDV = dv.MaLoaiDV AND loai.KieuTinhPhi = 'THANG'
    JOIN MatBang AS matbang ON matbang.MaCongTy = hoadon.MaCongTy AND matbang.MaToaNha = hoadon.MaToaNha
    JOIN NhanSu AS nhansu ON nhansu.MaCongTy = hoadon.MaCongTy
    CROSS JOIN CauHinh AS cauhinh;

    INSERT INTO ChiTietHoaDon(MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay)
    SELECT hoadon.MaHoaDon, 'DICH_VU_LUOT', NULL, logdv.MaDichVu,
        SUM(logdv.SoLuot), logdv.DonGiaApDung, 1
    FROM HoaDonThang AS hoadon
    JOIN NhanVienCongTy AS nv ON nv.MaCongTy = hoadon.MaCongTy
    JOIN ChiTietSuDungNV AS logdv ON logdv.MaNVCT = nv.MaNVCT
        AND logdv.NgaySuDung >= MAKEDATE(hoadon.Nam, 1) + INTERVAL (hoadon.Thang - 1) MONTH
        AND logdv.NgaySuDung < MAKEDATE(hoadon.Nam, 1) + INTERVAL hoadon.Thang MONTH
    JOIN DichVu AS dv ON dv.MaDichVu = logdv.MaDichVu AND dv.MaToaNha = hoadon.MaToaNha
    GROUP BY hoadon.MaHoaDon, logdv.MaDichVu, logdv.DonGiaApDung;

    INSERT INTO ChiPhiVanHanh(MaToaNha, Thang, Nam, LoaiChiPhi, SoTien, MoTa)
    SELECT tn.MaToaNha, ky.Thang, ky.Nam, chiphi.Loai, chiphi.Tien,
        CONCAT('Chi phí vận hành tháng ', ky.Thang, '/', ky.Nam)
    FROM ToaNha AS tn
    CROSS JOIN tmp_Ky AS ky
    CROSS JOIN (
        SELECT 'Điện nước' AS Loai, 12000000 AS Tien
        UNION ALL SELECT 'Bảo trì', 5000000
        UNION ALL SELECT 'Vật tư', 3000000
    ) AS chiphi;

    -- Kiem tra so luong; sai thi huy toan bo seed.
    SELECT COUNT(*) INTO v_SoDong FROM ChiTietSuDungNV;
    IF v_SoDong <> 7320 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'So log khong dung 7.320. Huy toan bo seed.', MYSQL_ERRNO = 51003;
    END IF;
    SELECT COUNT(*) INTO v_SoDong FROM HoaDonThang;
    IF v_SoDong <> 12 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'So hoa don, chi tiet hoac bang luong khong dung.', MYSQL_ERRNO = 51004;
    END IF;
    SELECT COUNT(*) INTO v_SoDong FROM ChiTietHoaDon;
    IF v_SoDong <> 60 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'So hoa don, chi tiet hoac bang luong khong dung.', MYSQL_ERRNO = 51004;
    END IF;
    SELECT COUNT(*) INTO v_SoDong FROM LuongThang;
    IF v_SoDong <> 18 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'So hoa don, chi tiet hoac bang luong khong dung.', MYSQL_ERRNO = 51004;
    END IF;

    COMMIT;

    DROP TEMPORARY TABLE IF EXISTS tmp_Ky;
    DROP TEMPORARY TABLE IF EXISTS tmp_Ngay;
    DROP TEMPORARY TABLE IF EXISTS tmp_So;
END$$
DELIMITER ;

CALL usp_TV3_NapDuLieuMau();
DROP PROCEDURE IF EXISTS usp_TV3_NapDuLieuMau;

SELECT 'Seed TV3 hoan tat' AS KetQua;
