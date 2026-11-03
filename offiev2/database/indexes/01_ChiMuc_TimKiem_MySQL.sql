/* ============================================================================
   CHỈ MỤC MYSQL CHO TÌM KIẾM VÀ LỌC (officev2)
   Chạy một lần trên QLToaNha_BCNF sau khi đã nạp schema (MySQL không có IF NOT EXISTS cho CREATE INDEX).
   Không tự chạy: cần chạy thủ công nếu muốn áp dụng.
   ============================================================================ */
USE QLToaNha_BCNF;

CREATE INDEX IX_CongTy_LinhVuc ON CongTy(LinhVuc);
CREATE INDEX IX_HopDongThue_CongTy_Ngay ON HopDongThue(MaCongTy, NgayBatDau);
CREATE INDEX IX_NhanVienCongTy_CongTy_Ten ON NhanVienCongTy(MaCongTy, HoTen);
CREATE INDEX IX_NhanVienToaNha_Loai ON NhanVienToaNha(MaToaNha, LoaiNV);
CREATE INDEX IX_HoaDonThang_TrangThai_Ngay ON HoaDonThang(TrangThai, NgayThanhToan);
CREATE INDEX IX_ChiTietSuDungNV_Ngay ON ChiTietSuDungNV(NgaySuDung);
