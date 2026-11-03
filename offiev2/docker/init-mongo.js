/* ============================================================================
   PHẦN 7 - CHUYỂN ĐỔI CSDL QUAN HỆ SANG NOSQL MONGODB (MỤC 7.6)
   Thành viên 7: Bùi Đoàn Quang Huy - CHHT045
   File: 06_MongoDB.js
   Hướng dẫn chạy trực tiếp trên máy cài MongoDB (không cần kết nối SQL Server):
       mongosh --file 06_MongoDB.js
   ============================================================================ */

const dbName = "QuanLyToaNha";
const database = db.getSiblingDB(dbName);

print("=== BƯỚC 1: KHỞI TẠO DATABASE QUANLYTOANHA ===");
database.toanha.drop();
database.hopdong_thue.drop();
database.nhatky_dichvu.drop();

print("=== BƯỚC 2: TẠO COLLECTION 'toanha' (NHÚNG DANH SÁCH VĂN PHÒNG TỪ DỮ LIỆU P3) ===");
database.createCollection("toanha");
database.toanha.insertMany([
    {
        _id: "TN01",
        maToaNha: "TN01",
        tenToaNha: "Tòa nhà Thăng Long Center",
        maSite: 1,
        diaChi: "Số 10 Duy Tân, Cầu Giấy, Hà Nội",
        soTang: 9,
        vanPhong: [
            { maVanPhong: "VP01", maViTri: "VT_TRONG", tang: 1, dienTich: 80, donGiaThueM2: 200000 },
            { maVanPhong: "VP02", maViTri: "VT_MAT_TIEN", tang: 2, dienTich: 120, donGiaThueM2: 250000 },
            { maVanPhong: "VP03", maViTri: "VT_TRONG", tang: 3, dienTich: 80, donGiaThueM2: 200000 },
            { maVanPhong: "VP04", maViTri: "VT_MAT_TIEN", tang: 4, dienTich: 120, donGiaThueM2: 250000 }
        ]
    },
    {
        _id: "TN02",
        maToaNha: "TN02",
        tenToaNha: "Tòa nhà Sông Hàn Business",
        maSite: 2,
        diaChi: "Số 120 Bạch Đằng, Hải Châu, Đà Nẵng",
        soTang: 10,
        vanPhong: [
            { maVanPhong: "VP05", maViTri: "VT_TRONG", tang: 1, dienTich: 80, donGiaThueM2: 200000 },
            { maVanPhong: "VP06", maViTri: "VT_MAT_TIEN", tang: 2, dienTich: 120, donGiaThueM2: 250000 },
            { maVanPhong: "VP07", maViTri: "VT_TRONG", tang: 3, dienTich: 80, donGiaThueM2: 200000 },
            { maVanPhong: "VP08", maViTri: "VT_MAT_TIEN", tang: 4, dienTich: 120, donGiaThueM2: 250000 }
        ]
    },
    {
        _id: "TN03",
        maToaNha: "TN03",
        tenToaNha: "Tòa nhà Sài Gòn Tower",
        maSite: 3,
        diaChi: "Số 25 Lê Duẩn, Quận 1, TP. Hồ Chí Minh",
        soTang: 11,
        vanPhong: [
            { maVanPhong: "VP09", maViTri: "VT_TRONG", tang: 1, dienTich: 80, donGiaThueM2: 200000 },
            { maVanPhong: "VP10", maViTri: "VT_MAT_TIEN", tang: 2, dienTich: 120, donGiaThueM2: 250000 },
            { maVanPhong: "VP11", maViTri: "VT_TRONG", tang: 3, dienTich: 80, donGiaThueM2: 200000 },
            { maVanPhong: "VP12", maViTri: "VT_MAT_TIEN", tang: 4, dienTich: 120, donGiaThueM2: 250000 }
        ]
    }
]);

print("=== BƯỚC 3: TẠO COLLECTION 'hopdong_thue' (6 CÔNG TY, 12 HỢP ĐỒNG & HÓA ĐƠN P3) ===");
database.createCollection("hopdong_thue");
database.hopdong_thue.insertMany([
    {
        _id: "HD_CT01_TN01",
        maCongTy: "CT01",
        tenCongTy: "Công ty TNHH Giải pháp Phần mềm Thăng Long",
        maSoThue: "0109000001",
        linhVuc: "Cong nghe thong tin",
        maToaNha: "TN01",
        maSite: 1,
        vanPhongThue: [
            { maHopDong: "HD01", maVanPhong: "VP01", tang: 1, dienTich: 80, donGiaThueM2: 200000 },
            { maHopDong: "HD02", maVanPhong: "VP02", tang: 2, dienTich: 120, donGiaThueM2: 250000 }
        ],
        tongDienTich: 200,
        ngayBatDau: ISODate("2026-07-01T00:00:00Z"),
        ngayKetThuc: ISODate("2027-06-30T00:00:00Z"),
        hoaDonThang: [
            { maHoaDon: 1, thang: 8, nam: 2026, trangThai: "DA_THANH_TOAN", ngayThanhToan: ISODate("2026-09-05T00:00:00Z"), tongTien: 60650000 },
            { maHoaDon: 2, thang: 9, nam: 2026, trangThai: "CHUA_THANH_TOAN", ngayThanhToan: null, tongTien: 60250000 }
        ]
    },
    {
        _id: "HD_CT02_TN01",
        maCongTy: "CT02",
        tenCongTy: "Công ty Cổ phần Thương mại Hoàng Hà",
        maSoThue: "0109000002",
        linhVuc: "Thuong mai",
        maToaNha: "TN01",
        maSite: 1,
        vanPhongThue: [
            { maHopDong: "HD03", maVanPhong: "VP03", tang: 3, dienTich: 80, donGiaThueM2: 200000 },
            { maHopDong: "HD04", maVanPhong: "VP04", tang: 4, dienTich: 120, donGiaThueM2: 250000 }
        ],
        tongDienTich: 200,
        ngayBatDau: ISODate("2026-07-01T00:00:00Z"),
        ngayKetThuc: ISODate("2027-06-30T00:00:00Z"),
        hoaDonThang: [
            { maHoaDon: 3, thang: 8, nam: 2026, trangThai: "DA_THANH_TOAN", ngayThanhToan: ISODate("2026-09-05T00:00:00Z"), tongTien: 60650000 },
            { maHoaDon: 4, thang: 9, nam: 2026, trangThai: "CHUA_THANH_TOAN", ngayThanhToan: null, tongTien: 60250000 }
        ]
    },
    {
        _id: "HD_CT03_TN02",
        maCongTy: "CT03",
        tenCongTy: "Công ty TNHH Tư vấn Tài chính Bình Minh",
        maSoThue: "0109000003",
        linhVuc: "Cong nghe thong tin",
        maToaNha: "TN02",
        maSite: 2,
        vanPhongThue: [
            { maHopDong: "HD05", maVanPhong: "VP05", tang: 1, dienTich: 80, donGiaThueM2: 200000 },
            { maHopDong: "HD06", maVanPhong: "VP06", tang: 2, dienTich: 120, donGiaThueM2: 250000 }
        ],
        tongDienTich: 200,
        ngayBatDau: ISODate("2026-07-01T00:00:00Z"),
        ngayKetThuc: ISODate("2027-06-30T00:00:00Z"),
        hoaDonThang: [
            { maHoaDon: 5, thang: 8, nam: 2026, trangThai: "DA_THANH_TOAN", ngayThanhToan: ISODate("2026-09-05T00:00:00Z"), tongTien: 60650000 },
            { maHoaDon: 6, thang: 9, nam: 2026, trangThai: "CHUA_THANH_TOAN", ngayThanhToan: null, tongTien: 60250000 }
        ]
    },
    {
        _id: "HD_CT04_TN02",
        maCongTy: "CT04",
        tenCongTy: "Công ty Cổ phần Logistics Sông Hồng",
        maSoThue: "0109000004",
        linhVuc: "Thuong mai",
        maToaNha: "TN02",
        maSite: 2,
        vanPhongThue: [
            { maHopDong: "HD07", maVanPhong: "VP07", tang: 3, dienTich: 80, donGiaThueM2: 200000 },
            { maHopDong: "HD08", maVanPhong: "VP08", tang: 4, dienTich: 120, donGiaThueM2: 250000 }
        ],
        tongDienTich: 200,
        ngayBatDau: ISODate("2026-07-01T00:00:00Z"),
        ngayKetThuc: ISODate("2027-06-30T00:00:00Z"),
        hoaDonThang: [
            { maHoaDon: 7, thang: 8, nam: 2026, trangThai: "DA_THANH_TOAN", ngayThanhToan: ISODate("2026-09-05T00:00:00Z"), tongTien: 60650000 },
            { maHoaDon: 8, thang: 9, nam: 2026, trangThai: "CHUA_THANH_TOAN", ngayThanhToan: null, tongTien: 60250000 }
        ]
    },
    {
        _id: "HD_CT05_TN03",
        maCongTy: "CT05",
        tenCongTy: "Công ty TNHH Dược phẩm An Khang",
        maSoThue: "0109000005",
        linhVuc: "Cong nghe thong tin",
        maToaNha: "TN03",
        maSite: 3,
        vanPhongThue: [
            { maHopDong: "HD09", maVanPhong: "VP09", tang: 1, dienTich: 80, donGiaThueM2: 200000 },
            { maHopDong: "HD10", maVanPhong: "VP10", tang: 2, dienTich: 120, donGiaThueM2: 250000 }
        ],
        tongDienTich: 200,
        ngayBatDau: ISODate("2026-07-01T00:00:00Z"),
        ngayKetThuc: ISODate("2027-06-30T00:00:00Z"),
        hoaDonThang: [
            { maHoaDon: 9, thang: 8, nam: 2026, trangThai: "DA_THANH_TOAN", ngayThanhToan: ISODate("2026-09-05T00:00:00Z"), tongTien: 60650000 },
            { maHoaDon: 10, thang: 9, nam: 2026, trangThai: "CHUA_THANH_TOAN", ngayThanhToan: null, tongTien: 60250000 }
        ]
    },
    {
        _id: "HD_CT06_TN03",
        maCongTy: "CT06",
        tenCongTy: "Công ty Cổ phần Đầu tư Sao Mai",
        maSoThue: "0109000006",
        linhVuc: "Thuong mai",
        maToaNha: "TN03",
        maSite: 3,
        vanPhongThue: [
            { maHopDong: "HD11", maVanPhong: "VP11", tang: 3, dienTich: 80, donGiaThueM2: 200000 },
            { maHopDong: "HD12", maVanPhong: "VP12", tang: 4, dienTich: 120, donGiaThueM2: 250000 }
        ],
        tongDienTich: 200,
        ngayBatDau: ISODate("2026-07-01T00:00:00Z"),
        ngayKetThuc: ISODate("2027-06-30T00:00:00Z"),
        hoaDonThang: [
            { maHoaDon: 11, thang: 8, nam: 2026, trangThai: "DA_THANH_TOAN", ngayThanhToan: ISODate("2026-09-05T00:00:00Z"), tongTien: 60650000 },
            { maHoaDon: 12, thang: 9, nam: 2026, trangThai: "CHUA_THANH_TOAN", ngayThanhToan: null, tongTien: 60250000 }
        ]
    }
]);

print("=== BƯỚC 4: TẠO COLLECTION 'nhatky_dichvu' (SINH ĐỦ 7.320 BẢN GHI NHƯ SEED P3) ===");
database.createCollection("nhatky_dichvu");
const bulkLogs = [];
let maSuDung = 1;
const months = [
    { month: 8, days: 31 },
    { month: 9, days: 30 }
];
for (let emp = 1; emp <= 60; emp++) {
    const maNVCT = "NVCT" + String(emp).padStart(3, "0");
    const ctyIdx = Math.floor((emp - 1) / 10) + 1;
    const maCongTy = "CT0" + ctyIdx;
    const siteIdx = Math.floor((ctyIdx - 1) / 2) + 1;
    const maToaNha = "TN0" + siteIdx;
    const services = [
        { maDichVu: "AN0" + siteIdx, loai: "AN_UONG", ten: "Bữa trưa", donGia: 35000 },
        { maDichVu: "XE0" + siteIdx, loai: "GUI_XE", ten: "Gửi xe máy", donGia: 5000 }
    ];
    for (const m of months) {
        for (let d = 1; d <= m.days; d++) {
            const dateStr = `2026-${String(m.month).padStart(2, "0")}-${String(d).padStart(2, "0")}T00:00:00Z`;
            for (const sv of services) {
                bulkLogs.push({
                    _id: maSuDung,
                    maSuDung: maSuDung,
                    maNVCT: maNVCT,
                    maCongTy: maCongTy,
                    maToaNha: maToaNha,
                    maSite: siteIdx,
                    ngaySuDung: ISODate(dateStr),
                    dichVu: {
                        maDichVu: sv.maDichVu,
                        loai: sv.loai,
                        ten: sv.ten,
                        soLuong: 1,
                        donGia: sv.donGia,
                        thanhTien: sv.donGia
                    }
                });
                maSuDung++;
            }
        }
    }
}
for (let i = 0; i < bulkLogs.length; i += 1000) {
    database.nhatky_dichvu.insertMany(bulkLogs.slice(i, i + 1000));
}
print(`Đã nạp thành công: toanha=${database.toanha.countDocuments()}, hopdong_thue=${database.hopdong_thue.countDocuments()}, nhatky_dichvu=${database.nhatky_dichvu.countDocuments()} (Khớp 7.320 dòng P3)`);

print("\n=== BƯỚC 5: THỰC THI CÁC TRUY VẤN MONGODB MINH HỌA ===");

print("\n--- Truy vấn 1: Tìm tòa nhà và danh sách văn phòng tại Site 1 (TN01) ---");
printjson(database.toanha.find({ maSite: 1 }).toArray());

print("\n--- Truy vấn 2: Tìm hợp đồng thuê và hóa đơn của công ty CT01 ---");
printjson(database.hopdong_thue.find({ maCongTy: "CT01" }).toArray());

print("\n--- Truy vấn 3: Thống kê tổng số lượt và doanh thu dịch vụ theo loại trên toàn chuỗi ---");
printjson(database.nhatky_dichvu.aggregate([
    {
        $group: {
            _id: "$dichVu.loai",
            tongSoLuot: { $sum: "$dichVu.soLuong" },
            tongDoanhThu: { $sum: "$dichVu.thanhTien" }
        }
    },
    { $sort: { _id: 1 } }
]).toArray());

print("\n--- Truy vấn 4: Thống kê số bản ghi nhật ký và doanh thu dịch vụ theo từng Site (TN01, TN02, TN03) ---");
printjson(database.nhatky_dichvu.aggregate([
    {
        $group: {
            _id: { maSite: "$maSite", maToaNha: "$maToaNha" },
            soBanGhiNhatKy: { $sum: 1 },
            doanhThuDichVuLuot: { $sum: "$dichVu.thanhTien" }
        }
    },
    { $sort: { "_id.maSite": 1 } }
]).toArray());

print("\n--- Truy vấn 5: Tổng hợp chi phí hóa đơn và số tiền đã thanh toán theo từng tòa nhà ---");
printjson(database.hopdong_thue.aggregate([
    { $unwind: "$hoaDonThang" },
    {
        $group: {
            _id: "$maToaNha",
            soHoaDon: { $sum: 1 },
            tongTienHoaDon: { $sum: "$hoaDonThang.tongTien" },
            tongDaThanhToan: {
                $sum: {
                    $cond: [{ $eq: ["$hoaDonThang.trangThai", "DA_THANH_TOAN"] }, "$hoaDonThang.tongTien", 0]
                }
            }
        }
    },
    { $sort: { _id: 1 } }
]).toArray());
