# Mô hình phân tán và cấu hình đặc biệt

Tài liệu này mô tả cách phân mảnh dữ liệu trên MySQL và MongoDB, lý do chọn cách đó, và các cấu hình đặc biệt cần biết khi vận hành.

## 1. Ý tưởng chung

Dữ liệu của hệ thống gắn gần như hoàn toàn với **tòa nhà**: hợp đồng thuê, hóa đơn, nhật ký dịch vụ và lương nhân viên đều thuộc về một tòa nhà. Vì vậy cả hai CSDL đều chọn **tòa nhà (`MaToaNha`) làm khóa phân mảnh**:

| Toà nhà | Thành phố | Site MySQL | Shard MongoDB (zone) |
| :--- | :--- | :--- | :--- |
| `TN01` Tòa nhà Thăng Long Center | Hà Nội | `QLToaNha_Site1` (trung tâm) | `shard1RS` (tag `TN01`) |
| `TN02` Tòa nhà Sông Hàn Business | Đà Nẵng | `QLToaNha_Site2` | `shard2RS` (tag `TN02`) |
| `TN03` Tòa nhà Sài Gòn Tower | TP. Hồ Chí Minh | `QLToaNha_Site3` | `shard3RS` (tag `TN03`) |

Lý do chọn tòa nhà làm khóa:

- Mọi nghiệp vụ tài chính (hóa đơn tháng, chốt lương, thu tiền) chạy theo từng tòa nhà.
- Phần lớn truy vấn có điều kiện `MaToaNha`, nên một truy vấn chỉ cần đụng một site/shard.
- Ba tòa nhà tương ứng ba chi nhánh địa lý, nên dữ liệu của mỗi tòa nằm gần nơi phát sinh nghiệp vụ.

## 2. MySQL: phân mảnh ngang, dẫn xuất và dọc

CSDL trung tâm `QLToaNha_BCNF` có đủ 18 bảng BCNF. Ba site là các CSDL riêng, mỗi site là một **node** (một server MySQL riêng trong Docker Compose). Cách phân mảnh (chi tiết trong `database/distributed/01_TaoSite_Template_TV7_BuiDoanQuangHuy.sql`):

| Loại mảnh | Bảng | Điều kiện / cách tạo | Ghi chú |
| :--- | :--- | :--- | :--- |
| Ngang chính | `ToaNha`, `VanPhong`, `DichVu`, `NhanVienToaNha`, `HoaDonThang`, `ChiPhiVanHanh` | `MaToaNha = TN0x` | Mỗi site chỉ giữ một tòa nhà. |
| Ngang dẫn xuất (semi-join) | `HopDongThue` | `MaVanPhong` thuộc tòa nhà | Hợp đồng theo văn phòng của tòa nhà. |
| Ngang dẫn xuất | `ChiTietSuDungNV` | `MaDichVu` thuộc tòa nhà | Nhật ký dịch vụ theo dịch vụ của tòa nhà. |
| Ngang dẫn xuất | `PhanCongNVTN`, `LuongThang_Ky`, `ChiTietHoaDon`, `SuDungDichVu` | Theo nhân viên / hóa đơn / dịch vụ của tòa nhà | Lịch sử phân công và khóa kỳ lương. |
| Dọc | `CongTy` → `CongTy_TraCuu` (tên, lĩnh vực) và `CongTy_HoSo` (MST, địa chỉ, liên hệ) | `CongTy_HoSo` chỉ có ở site trung tâm | Hồ sơ thuế là thông tin nhạy cảm. |
| Dọc | `LuongThang` → `LuongThang_Ky` (khóa kỳ) và `LuongThang_Tien` (số tiền) | `LuongThang_Tien` chỉ có ở site trung tâm | Tiền lương tập trung tại trung tâm. |
| Nhân bản tra cứu | `ThamSo`, `ViTri`, `LoaiDichVu`, `BacCongViec_TraCuu`, `CongTy_TraCuu` | Copy toàn bộ | Dữ liệu danh mục nhỏ, cần ở mọi site để JOIN. |

**Tái thiết và kiểm tra đầy đủ.** Phép hợp các mảnh ngang của một bảng phải bằng bảng gốc (không mất, không trùng); phép nối các mảnh dọc theo khóa phải bằng bảng gốc. Đối soát này được thực hiện tự động trong trang `GET /api/tv7/distribution` (mục `sites[].checks`, `checks`): mỗi site so với trung tâm theo ID và theo nội dung. Trạng thái `matched` nghĩa là số lượng và danh sách khóa khớp.

**Giới hạn cần biết của MySQL trong bản này:**

- Các site được **lập từ trung tâm** khi khởi tạo (`docker/init-db.sh`), không phải đồng bộ thời gian thực. Nếu dữ liệu trung tâm thay đổi sau đó, site phải được lập lại.
- Mọi giao dịch ghi (hợp đồng, hóa đơn, thanh toán, lương, nhật ký) hiện **chạy trên CSDL trung tâm**. Site là bản sao phục vụ đối soát và báo cáo phân tán, chưa nhận ghi trực tiếp.
- Ba site nằm trên ba server MySQL khác nhau nhưng khởi tạo bằng một container `db-init` (đóng vai trò người điều phối).

## 3. MongoDB: cụm sharded với zone theo tòa nhà

MongoDB chạy như **cụm sharded thật** gồm: 1 config server (replica set `cfgRS`), 3 shard (`shard1RS`, `shard2RS`, `shard3RS`, mỗi shard là một replica set một node), và 1 router `mongos` (cổng `27017`, ứng dụng và Compass kết nối vào đây).

### 3.1. Khóa phân mảnh và zone

Ba collection đều shard theo **`{ maToaNha: 1 }`**:

| Collection | Nội dung | Vì sao shard theo `maToaNha` |
| :--- | :--- | :--- |
| `toanha` | Thông tin tòa nhà, danh sách văn phòng nhúng (`vanPhong`) | Mỗi tòa nhà một tài liệu; đọc tòa nhà là đọc một shard. |
| `hopdong_thue` | Hợp đồng của công ty trong tòa nhà: `vanPhongThue`, `hoaDonThang` nhúng | Hợp đồng và hóa đơn gắn tòa nhà; báo cáo đối soát theo tòa. |
| `nhatky_dichvu` | Nhật ký sử dụng dịch vụ (7.320 bản ghi mẫu) | Khối lượng ghi lớn nhất; truy vấn thường theo tòa và khoảng ngày. |

Zone (`sh.addShardTag` và `sh.updateZoneKeyRange`) gán dải khóa cho từng shard:

- `TN01` → shard `shard1RS`, dải `["TN01", "TN02")`
- `TN02` → shard `shard2RS`, dải `["TN02", "TN03")`
- `TN03` → shard `shard3RS`, dải `["TN03", MaxKey)`

Nhờ đó dữ liệu của mỗi tòa nhà **nằm đúng shard ứng với site MySQL**. Balancer tự di chuyển chunk vào đúng zone.

### 3.2. Lý do chọn cách phân mảnh này

1. **Tính cục bộ theo tòa nhà.** Đọc/ghi của một tòa chỉ chạm một shard, giảm truy vấn phân tán (scatter-gather) cho các màn hình vận hành tòa nhà.
2. **Đồng nhất với MySQL.** Cùng một khóa (`MaToaNha`) và cùng một ánh xạ tòa → site/shard, nên đối soát giữa hai hệ thống là đối soát theo cùng một đơn vị.
3. **Dữ liệu nhúng theo tòa.** `toanha` nhúng danh sách văn phòng, `hopdong_thue` nhúng hợp đồng và hóa đơn: một lần đọc lấy đủ thông tin cần cho báo cáo, không cần JOIN (MongoDB không có JOIN tốt như SQL).
4. **Khối lượng nhật ký.** `nhatky_dichvu` lớn nhất và tăng theo thời gian; zone đảm bảo nhật ký của một tòa không làm nóng shard của tòa khác.

### 3.3. Giới hạn của khóa `maToaNha`

- Chỉ có 3 giá trị khóa, nên **không thể chia một tòa nhà ra nhiều shard**. Nếu một tòa vượt khả năng một shard, cần đổi khóa của `nhatky_dichvu` thành `{ maToaNha: 1, ngaySuDung: 1 }` (khóa hợp chất) và tách dải theo ngày. Bản này chưa làm điều đó.
- `_id` chỉ được đảm bảo duy nhất **trong từng shard**. Hiện tại mỗi tòa một shard nên không trùng; nếu sau này một tòa trải nhiều shard, `_id` phải được tạo duy nhất toàn cục.

### 3.4. Cấu hình đặc biệt cần biết

- **Xác thực nội bộ bằng keyfile.** Container `mongo-keygen` sinh file khóa ngẫu nhiên vào volume `mongo_keyfile` (quyền `400`, chủ sở hữu `999`). Mọi node (config, shard, mongos) đều dùng chung keyfile. Keyfile làm bật xác thực cho cả cụm.
- **Khởi tạo bằng localhost exception.** Mỗi node tự khởi tạo replica set khi chạy trên localhost (`docker/mongo-node.sh`), vì khi chưa có user thì localhost exception cho phép các lệnh khởi tạo. User quản trị được tạo trên **config server**; mongos xác thực bằng user này. Localhost exception **không** áp dụng cho mongos khi đã bật keyfile, nên không tạo user qua mongos.
- **Thứ tự nạp dữ liệu.** Dữ liệu mẫu (`docker/init-mongo.js`) được nạp **trước** khi bật sharding; sau đó tạo index `{maToaNha:1}`, bật sharding và gán zone. Việc này cho phép shardCollection trên collection đã có dữ liệu.
- **Orphan và thời gian chờ dọn dẹp.** Sau khi balancer chuyển chunk, shard cũ giữ bản ghi "mồ côi" đến khi range deleter chạy, mặc định sau `orphanCleanupDelaySecs = 900` giây (15 phút). Trong khoảng này `$collStats` đếm cả bản ghi mồ côi; truy vấn qua mongos vẫn trả đúng kết quả.
- **Số config server.** Chỉ 1 node cho demo; MongoDB cảnh báo khi dưới 3 node. Môi trường thật phải dùng 3 node config server.
- **Không có TLS.** Kết nối Compass và ứng dụng đi qua mạng nội bộ Docker, chưa mã hóa.

## 4. Tóm tắt cho người vận hành

| Thành phần | Chế độ | Khóa | Cổng host |
| :--- | :--- | :--- | :--- |
| MySQL trung tâm + site 1 | 1 server, 2 CSDL | `MaToaNha` | `3306` |
| MySQL site 2 | 1 server, 1 CSDL | `MaToaNha` | `3307` |
| MySQL site 3 | 1 server, 1 CSDL | `MaToaNha` | `3308` |
| MongoDB | sharded cluster, 3 shard, zone theo tòa | `maToaNha` | `27017` (mongos) |

Kiểm tra sau khi triển khai:

- `GET http://localhost:3000/api/tv7/distribution`: tất cả `matched`.
- `docker compose logs mongos`: có dòng `[OK] MongoDB sharded cluster san sang`.
- Trong `mongosh` đã xác thực: `sh.status()` liệt kê 3 shard có tag `TN01`, `TN02`, `TN03`.
