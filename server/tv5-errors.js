const messages = {
  55101: "Văn phòng đã có hợp đồng thuê trùng khoảng thời gian này.",
  55201: "Công ty cần có hợp đồng thuê tại tòa nhà cung cấp dịch vụ trong kỳ đăng ký.",
  55301: "Công ty của nhân viên chưa đăng ký dịch vụ tại thời điểm sử dụng.",
  55302: "Nhân viên không còn làm việc tại ngày sử dụng dịch vụ.",
  55303: "Ngày sử dụng dịch vụ không được sau ngày hôm nay.",
  55304: "Chỉ dịch vụ tính phí theo lượt mới được ghi nhật ký sử dụng.",
  55305: "Công ty cần có hợp đồng thuê còn hiệu lực tại tòa nhà cung cấp dịch vụ vào ngày sử dụng.",
  55401: "Không thể xóa công ty vì còn dữ liệu liên quan. Hãy xử lý các bản ghi phụ thuộc trước.",
  55402: "Không thể xóa tòa nhà vì còn dữ liệu liên quan. Hãy xử lý các bản ghi phụ thuộc trước."
};

function tv5Error(error) {
  const number = Number(error?.number ?? error?.originalError?.info?.number);
  if (!Number.isInteger(number) || number < 55000 || number > 55999) return null;
  return { code: String(number), message: messages[number] || "Thao tác bị từ chối bởi quy tắc dữ liệu TV5." };
}

module.exports = { tv5Error };
