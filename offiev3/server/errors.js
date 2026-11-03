// Lỗi nghiệp vụ dùng chung. `errno` giữ mã nghiệp vụ (51xxx theo TV4, 55xxx theo TV5) để
// index.js ánh xạ sang HTTP 409/422 như bản MySQL.
class ValidationError extends Error {}

const businessMessages = {
  51001: "Không lấy được khóa nghiệp vụ. Hãy thử lại.",
  51101: "Ngày thuê hoặc danh sách phòng không hợp lệ.",
  51102: "Công ty hoặc tòa nhà không tồn tại.",
  51103: "Văn phòng không tồn tại hoặc không thuộc tòa nhà đã chọn.",
  51105: "Khoảng thuê trùng với kỳ đã có hóa đơn.",
  51106: "Có văn phòng trùng lịch thuê. Toàn bộ lô đã được hủy.",
  51201: "Lô rỗng, số lượt không hợp lệ hoặc ngày sử dụng trong tương lai.",
  51202: "Nhân viên, dịch vụ, đăng ký hoặc hợp đồng không hợp lệ vào ngày sử dụng.",
  51203: "Không thể ghi nhật ký vào kỳ đã phát hành hóa đơn.",
  51204: "Lô có nhật ký đã được ghi nhận. Không cộng dồn ngầm.",
  51301: "Tháng hoặc năm không hợp lệ.",
  51302: "Chỉ phát hành hóa đơn khi tháng đã kết thúc.",
  51303: "Tòa nhà không tồn tại.",
  51304: "Kỳ đã có hóa đơn. Không ghi đè hoặc lập bổ sung ngầm.",
  51305: "Thiếu hoặc sai tham số bậc thang.",
  51306: "Dữ liệu hợp đồng nguồn bị chồng lịch.",
  51307: "Đăng ký dịch vụ tháng có ngày không có hợp đồng thuê cùng tòa.",
  51308: "Kỳ không có khoản thu để lập hóa đơn.",
  51401: "Mã hóa đơn, số tiền và ngày thanh toán không hợp lệ.",
  51402: "Hóa đơn không tồn tại.",
  51403: "Hóa đơn đã được thanh toán.",
  51404: "Tên người thu không được để toàn khoảng trắng.",
  51405: "Ngày thanh toán phải từ ngày lập hóa đơn đến hôm nay.",
  51406: "Số tiền phải khớp đúng tổng hóa đơn; chỉ hỗ trợ trả đủ một lần.",
  51407: "Không cập nhật được trạng thái thanh toán.",
  51501: "Tháng hoặc năm không hợp lệ.",
  51502: "Phải phát hành hóa đơn tòa nhà trước khi chốt lương.",
  51503: "Kỳ đã có lương. Không tính lại hoặc ghi đè.",
  51505: "Có nhân viên chưa được phân công trong tháng.",
  51506: "Phân công, bậc lương hoặc dịch vụ không hợp lệ.",
  51507: "Tòa nhà phải có đúng một quản lý trong tháng.",
  51508: "Không có nhân viên để tính lương.",
  51509: "Còn công ty chưa được lập hóa đơn trong kỳ.",
  55101: "Văn phòng đã có hợp đồng thuê trùng khoảng thời gian này.",
  55401: "Không thể xóa công ty vì còn dữ liệu liên quan. Hãy xử lý các bản ghi phụ thuộc trước.",
  55402: "Không thể xóa tòa nhà vì còn dữ liệu liên quan. Hãy xử lý các bản ghi phụ thuộc trước."
};

// Tạo lỗi nghiệp vụ với mã số và thông báo tiếng Việt.
function businessError(code, message = businessMessages[code] || "Thao tác bị từ chối bởi quy tắc nghiệp vụ.") {
  const error = new Error(message);
  error.errno = code;
  return error;
}

module.exports = { ValidationError, businessError, businessMessages };
