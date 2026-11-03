# Thiết kế MongoDB phân mảnh (officev3)

Tài liệu này mô tả thiết kế CSDL MongoDB của officev3: vì sao gộp các bảng thành collection, khác gì so với MySQL (officev2), cách phân mảnh, và các cấu hình đặc biệt.

## 1. Tóm tắt

| Hạng mục | MySQL (officev2) | MongoDB (officev3) |
| :--- | :--- | :--- |
| Mô hình | 18 bảng BCNF, chuẩn hóa, khóa ngoại | 10 collection, tài liệu nhúng theo truy vấn |
| Quan hệ | JOIN khi đọc | Nhúng khi đọc cùng lúc, tham chiếu bằng mã khi cần |
| Phân tán | 3 CSDL/server, mảnh tạo từ trung tâm | Cụm sharded: config server + 3 shard + mongos, zone theo tòa |
| Ràng buộc | Khóa ngoại, CHECK, trigger TV5 | Chỉ mục duy nhất + kiểm tra trong code giao dịch |
| Giao dịch TV4 | Stored procedure, GET_LOCK | Hàm JavaScript trong multi-document transaction |
| Báo cáo | SQL JOIN, window function | Aggregation và tra cứu tên trong bộ nhớ |
| Tiền | DECIMAL(18,2) | Số làm tròn 2 chữ số (xem mục 6) |

Giao diện, hợp đồng REST, kiểm tra dữ liệu đầu vào và cấu trúc thư mục web được giữ nguyên.

## 2. Vì sao gộp bảng thành collection

Trong MySQL, mỗi nghiệp vụ được chia thành nhiều bảng để tránh dư thừa (BCNF). Đổi lại, một câu hỏi như "hóa đơn của công ty X tháng 8 gồm những dòng nào" cần JOIN nhiều bảng. MongoDB đọc tốt nhất khi dữ liệu đi cùng nhau nằm trong **một tài liệu**, vì một lần đọc (một shard, một document) đã đủ.

Quy tắc gộp dùng trong officev3:

1. **Nhúng khi thuộc về cha và có số lượng giới hạn** (ví dụ: văn phòng, dịch vụ, nhân viên toà nhà nhúng trong tài liệu toà; dòng hóa đơn nhúng trong hóa đơn; dịch vụ đăng ký nhúng trong công ty). Số lượng nhỏ, luôn được đọc cùng cha.
2. **Tham chiếu bằng mã** khi thực thể có vòng đời riêng hoặc tăng không giới hạn (hợp đồng, nhật ký sử dụng, bảng lương, chi phí).
3. **Danh mục nhỏ tách riêng** (thông số, vị trí, loại dịch vụ, bậc lương) vì được tra cứu chung và không thay đổi thường xuyên.

Ánh xạ 18 bảng → collection:

| Bảng MySQL | Collection MongoDB | Ghi chú |
| :--- | :--- | :--- |
| `ThamSo` | `thong_so` | Danh mục, không shard |
| `ViTri` | `vi_tri` | Danh mục, không shard |
| `LoaiDichVu` | `loai_dich_vu` | Danh mục, không shard |
| `BacCongViec` | `bac_cong_viec` | Danh mục, không shard |
| `ToaNha`, `VanPhong`, `DichVu`, `NhanVienToaNha`, `PhanCongNVTN` | `toa_nha` | Nhúng văn phòng, dịch vụ, nhân viên và phân công theo tháng |
| `CongTy`, `SuDungDichVu` | `cong_ty` | Nhúng dịch vụ đăng ký |
| `NhanVienCongTy` | `nhan_vien_cong_ty` | Tách vì số lượng lớn hơn |
| `HopDongThue` | `hop_dong_thue` | Tham chiếu công ty và văn phòng |
| `HoaDonThang`, `ChiTietHoaDon` | `hoa_don_thang` | Nhúng dòng hóa đơn (`chiTiet`) |
| `ChiTietSuDungNV` | `nhat_ky_su_dung` | Tăng theo thời gian, tách riêng |
| `LuongThang` | `bang_luong` | Tách riêng, khóa theo kỳ |
| `ChiPhiVanHanh` | `chi_phi_van_hanh` | Theo toà và kỳ |
| `V_ChiTietHoaDon` (view) | Không có | Thành tiền lưu sẵn trong `chiTiet.soTien` |
| (mới) | `bo_dem` | Bộ đếm sinh mã hóa đơn tăng nguyên tử |

Kết quả: 18 bảng thành 10 collection cùng một bộ đếm. Mô hình phản ánh cách đọc của ứng dụng, không phản ánh cách lưu của chuẩn hóa.

## 3. Phân mảnh (sharding)

### 3.1. Khóa phân mảnh

| Collection | Khóa | Lý do |
| :--- | :--- | :--- |
| `toa_nha`, `hop_dong_thue`, `hoa_don_thang`, `nhat_ky_su_dung`, `bang_luong`, `chi_phi_van_hanh` | `{ maToaNha: 1 }` (dải + zone) | Mọi nghiệp vụ tài chính và vận hành đều theo tòa nhà. Một truy vấn theo tòa chỉ chạm một shard. |
| `cong_ty` | `{ _id: "hashed" }` | Công ty không thuộc riêng một tòa; băm để phân tán đều. |
| `nhan_vien_cong_ty` | `{ maCongTy: "hashed" }` | Nhân viên đi theo công ty; băm đều. |
| Danh mục | Không shard | Nhỏ, đọc nhiều. |

### 3.2. Zone theo tòa nhà

| Zone | Dải khóa | Shard |
| :--- | :--- | :--- |
| `TN01` | `["TN01", "TN02")` | `shard1RS` |
| `TN02` | `["TN02", "TN03")` | `shard2RS` |
| `TN03` | `["TN03", MaxKey]` | `shard3RS` |

Mỗi zone là một tòa nhà, tương ứng một chi nhánh địa lý. Dữ liệu của tòa nằm trên shard của tòa đó.

### 3.3. Lý do chọn `maToaNha` làm khóa

1. **Cô lập theo nghiệp vụ.** Hóa đơn, lương và nhật ký của một toà được tính độc lập theo toà.
2. **Truy vấn định tuyến đúng shard.** Mọi giao dịch theo toà đều có `maToaNha` trong điều kiện, nên mongos chỉ gửi đến một shard.
3. **Đồng nhất với mô hình site ở officev2.** Cùng một ánh xạ toà → chi nhánh.

Giới hạn: chỉ có 3 giá trị khóa, nên không chia được một toà ra nhiều shard. Nếu một toà quá lớn, cần khóa hợp chất `{ maToaNha, ngaySuDung }` cho `nhat_ky_su_dung` và dải theo ngày (chưa làm).

## 4. Chỉ mục và ràng buộc

Collection đã shard chỉ cho phép chỉ mục duy nhất khi khóa phân mảnh là tiền tố của chỉ mục. Vì vậy:

| Collection | Chỉ mục duy nhất | Thay cho ràng buộc MySQL |
| :--- | :--- | :--- |
| `hoa_don_thang` | `{ maToaNha, maHoaDon }` và `{ maToaNha, maCongTy, nam, thang }` | `UQ_HoaDonThang_Ky`, khóa hóa đơn |
| `nhat_ky_su_dung` | `{ maToaNha, maNVCT, maDichVu, ngaySuDung }` | `UQ_ChiTietSuDungNV_Ngay` |
| `bang_luong` | `{ maToaNha, maNVTN, nam, thang }` | Khóa kỳ lương |

Các ràng buộc khác của MySQL (CHECK, khóa ngoại, trigger TV5) được kiểm tra trong `server/mongo/transactions.js` và `server/mongo/store.js`, trước khi ghi. Mã lỗi giữ nguyên dải 51xxx và 55xxx để giao diện không đổi.

## 5. Giao dịch TV4

Năm nghiệp vụ (ký thuê, ghi nhật ký, lập hóa đơn, thanh toán, chốt lương) chạy trong **multi-document transaction** với snapshot và `w: majority`.

Thay cho khóa `sp_getapplock`/`GET_LOCK`, mỗi giao dịch tăng `version` trong tài liệu toà. Hai giao dịch cùng toà sẽ xung đột ghi, MongoDB huỷ một bên, và API trả lỗi `TRANSACTION_CONFLICT` để người dùng thử lại. Đây là khóa lạc quan theo toà.

Công thức tiền nằm trong `server/mongo/billing.js`, là hàm thuần không truy cập CSDL. Cùng hàm được dùng cho giao dịch thật và cho bộ seed, nên dữ liệu sinh ra và dữ liệu giao dịch luôn theo cùng quy tắc.

## 6. Khác biệt cần biết

- **Ngày** lưu dạng chuỗi `YYYY-MM-DD`. So sánh chuỗi đúng thứ tự và không phụ thuộc múi giờ. Tuy nhiên không có kiểu ngày của MongoDB nên không có chỉ mục theo khoảng thời gian tối ưu.
- **Tiền** lưu dạng số kiểu double đã làm tròn 2 chữ số bằng `money()`. Với dữ liệu hiện tại kết quả khớp, nhưng khác với `DECIMAL` của MySQL. Môi trường thật nên dùng `Decimal128`.
- **Mã hóa đơn** lấy từ bộ đếm `bo_dem`, là số nguyên như bản MySQL. Tra cứu hóa đơn chỉ theo `maHoaDon` (không kèm toà) phải quét mọi shard; thanh toán dùng cách này nên có chi phí phân tán.
- **Báo cáo** dùng aggregation cho lọc và gom; tên công ty, toà, dịch vụ được tra trong bộ nhớ sau đó.
- **Không có trigger**: các kiểm tra TV5 nằm trong code giao dịch và code cập nhật.

## 7. Cấu hình đặc biệt

- **Keyfile** do container `mongo-keygen` sinh vào volume `mongo_keyfile` (quyền 400, chủ `999`). Mọi node dùng chung keyfile để xác thực nội bộ.
- **Localhost exception.** Mỗi node tự khởi tạo replica set khi chạy trên localhost. User quản trị được tạo trên config server, vì mongos không dùng được localhost exception khi bật keyfile.
- **Thứ tự khởi động.** Cụm (`docker/mongo-node.sh`) thêm shard, bật sharding và gắn zone trước. Sau đó container `db-init` chạy `database/seed/seed.js` qua mongos. Seed chỉ xóa dữ liệu cũ, giữ nguyên cấu hình sharding.
- **Thống kê shard.** Không dùng `$collStats`/`estimatedDocumentCount` cho số bản ghi vì đây là số metadata, có thể đếm dư khi còn bản mồ côi. Số liệu thật lấy bằng `$group` theo tòa, ánh xạ tòa → shard qua tag zone.
- **Bản ghi mồ côi.** Sau khi balancer chuyển chunk, shard cũ giữ bản ghi mồ côi đến khi range deleter chạy (mặc định 900 giây).
- **Một config server** cho môi trường demo. Môi trường thật cần 3 node.
- **Không có TLS.** Kết nối đi trong mạng nội bộ Docker.

## 8. Dữ liệu mẫu

Seed (`database/seed/seed.js`) sinh dữ liệu bằng bộ số giả ngẫu nhiên có seed cố định. Nội dung: 3 toà ở Hà Nội, Đà Nẵng và TP.HCM; 6 công ty; 60 nhân viên công ty (một người nghỉ việc giữa tháng 9); 9 nhân viên toà; 12 hợp đồng; 2793 nhật ký dịch vụ (ngày làm việc, số lượt biến thiên); chi phí biến thiên theo tháng; 12 hóa đơn và 18 bản ghi lương được tính bằng `billing.js`. Hóa đơn tháng 8 đã thanh toán, tháng 9 chưa.

Dữ liệu này là bộ dữ liệu riêng của MongoDB, không sao chép từ MySQL. Hai bên không tự đồng bộ.
