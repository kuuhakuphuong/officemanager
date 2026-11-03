// Thiết kế collection MongoDB (xem docs/THIET_KE_MONGODB.md).
// Mỗi collection có: khóa phân mảnh (shardKey), các chỉ mục duy nhất (phải chứa tiền tố khóa phân mảnh
// với collection đã shard) và vai trò.

const COLLECTIONS = {
  // Danh mục tham chiếu nhỏ: không shard, được nhân bản ở mọi shard.
  thongSo: { name: "thong_so", kind: "reference" },
  viTri: { name: "vi_tri", kind: "reference" },
  loaiDichVu: { name: "loai_dich_vu", kind: "reference" },
  bacCongViec: { name: "bac_cong_viec", kind: "reference" },
  // Dữ liệu theo tòa nhà: shard theo maToaNha, zone theo site.
  toaNha: { name: "toa_nha", kind: "building", indexes: [] },
  hopDongThue: { name: "hop_dong_thue", kind: "building", indexes: [{ maToaNha: 1, maVanPhong: 1, ngayBatDau: 1 }] },
  hoaDonThang: {
    name: "hoa_don_thang", kind: "building",
    indexes: [
      { maToaNha: 1, maCongTy: 1, nam: 1, thang: 1 },
      { maToaNha: 1, maHoaDon: 1 }
    ]
  },
  nhatKySuDung: {
    name: "nhat_ky_su_dung", kind: "building",
    indexes: [{ maToaNha: 1, maNVCT: 1, maDichVu: 1, ngaySuDung: 1 }]
  },
  bangLuong: {
    name: "bang_luong", kind: "building",
    indexes: [{ maToaNha: 1, maNVTN: 1, nam: 1, thang: 1 }]
  },
  chiPhiVanHanh: { name: "chi_phi_van_hanh", kind: "building", indexes: [{ maToaNha: 1, nam: 1, thang: 1 }] },
  // Dữ liệu theo công ty: shard băm theo _id (phân tán đều, không gắn tòa nhà).
  congTy: { name: "cong_ty", kind: "hashed", shardKey: { _id: "hashed" } },
  nhanVienCongTy: { name: "nhan_vien_cong_ty", kind: "hashed", shardKey: { maCongTy: "hashed" } },
  // Bộ đếm sinh mã hóa đơn (tăng nguyên tử bằng findOneAndUpdate).
  boDem: { name: "bo_dem", kind: "reference" }
};

// Khóa phân mảnh cho các collection theo tòa nhà (shard theo dải, gắn zone).
const BUILDING_SHARD_KEY = { maToaNha: 1 };

// Chỉ mục nhìn từ ứng dụng: mỗi chỉ mục dùng để tra cứu nhanh một luồng nghiệp vụ.
function buildingCollections() {
  return Object.values(COLLECTIONS).filter((c) => c.kind === "building");
}

module.exports = { COLLECTIONS, BUILDING_SHARD_KEY, buildingCollections };
