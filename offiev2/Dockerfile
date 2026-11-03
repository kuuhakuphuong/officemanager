# ==============================================================================
# Dockerfile: Đóng gói ứng dụng Web Quản lý Tòa nhà
# Người xây dựng & đóng gói: Thành viên 7 - Bùi Đoàn Quang Huy (CHHT045)
# ==============================================================================
FROM node:22-alpine

WORKDIR /app

# Đặt biến môi trường sản xuất
ENV NODE_ENV=production

# Tối ưu hóa layer cache: copy dependency manifests trước
COPY package*.json ./

# Cài đặt production dependencies
RUN npm ci --omit=dev

# Copy toàn bộ mã nguồn ứng dụng
COPY . .

# Expose cổng web mặc định
EXPOSE 3000

# Khởi chạy Express server
CMD ["node", "server/index.js"]
