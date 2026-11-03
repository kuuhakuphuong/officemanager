#!/bin/bash
# ==============================================================================
# Script kiểm thử Stored Procedures Transactions TV4 (Linux / Docker Bash)
# Tác giả: Vũ Trung Hiếu (TV4) & Đóng gói: Bùi Đoàn Quang Huy (TV7)
# ==============================================================================
set -eo pipefail

SERVER="${DB_SERVER:-localhost}"
PORT="${DB_PORT:-1433}"
USER="${DB_USER:-sa}"
PASSWORD="${MSSQL_SA_PASSWORD:-Password123!}"
DATABASE="${1:-QLToaNha_TV4_Test_18Bang}"

SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
if [ ! -f "$SQLCMD" ]; then
    SQLCMD="/opt/mssql-tools/bin/sqlcmd"
fi
if [ ! -f "$SQLCMD" ]; then
    SQLCMD="sqlcmd"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="$(dirname "$SCRIPT_DIR")"

echo "======================================================"
echo " KIEM THU TRANSACTIONS TV4 TREN DATABASE: $DATABASE "
echo "======================================================"

# 1. Tao Database test
$SQLCMD -S "$SERVER,$PORT" -U "$USER" -P "$PASSWORD" -C -Q "IF DB_ID(N'$DATABASE') IS NOT NULL DROP DATABASE [$DATABASE]; CREATE DATABASE [$DATABASE];"

# 2. Nap Schema, Seed, Validate
sed "s/QLToaNha_BCNF/$DATABASE/g" "$DB_DIR/schema/01_CreateSchema_TV3_NguyenThiLanAnh.sql" | $SQLCMD -S "$SERVER,$PORT" -U "$USER" -P "$PASSWORD" -C
sed "s/QLToaNha_BCNF/$DATABASE/g" "$DB_DIR/schema/02_InsertSeedData_TV3_NguyenThiLanAnh.sql" | $SQLCMD -S "$SERVER,$PORT" -U "$USER" -P "$PASSWORD" -C
sed "s/QLToaNha_BCNF/$DATABASE/g" "$DB_DIR/schema/03_Validate_TV3_NguyenThiLanAnh.sql" | $SQLCMD -S "$SERVER,$PORT" -U "$USER" -P "$PASSWORD" -C

# 3. Nap Triggers TV5
$SQLCMD -S "$SERVER,$PORT" -U "$USER" -P "$PASSWORD" -C -d "$DATABASE" -i "$DB_DIR/triggers/05_Phan5_Triggers_TV5_KhucTuanAnh.sql"

# 4. Nap Transactions TV4
$SQLCMD -S "$SERVER,$PORT" -U "$USER" -P "$PASSWORD" -C -d "$DATABASE" -i "$SCRIPT_DIR/02_KiemTraTuongThich_TV4_VuTrungHieu.sql"
$SQLCMD -S "$SERVER,$PORT" -U "$USER" -P "$PASSWORD" -C -d "$DATABASE" -i "$SCRIPT_DIR/00_TaoKieuDuLieu_TV4_VuTrungHieu.sql"
$SQLCMD -S "$SERVER,$PORT" -U "$USER" -P "$PASSWORD" -C -d "$DATABASE" -i "$SCRIPT_DIR/03_Transactions_TV4_VuTrungHieu.sql"

# 5. Chay Kiem thu
$SQLCMD -S "$SERVER,$PORT" -U "$USER" -P "$PASSWORD" -C -d "$DATABASE" -i "$SCRIPT_DIR/04_KiemThu_TV4_VuTrungHieu.sql"
$SQLCMD -S "$SERVER,$PORT" -U "$USER" -P "$PASSWORD" -C -d "$DATABASE" -i "$SCRIPT_DIR/06_DoiChieuSeed_TV4_VuTrungHieu.sql"

echo "======================================================"
echo " [SUCCESS] KIEM THU TRANSACTIONS TV4 HOAN TAT! "
echo "======================================================"
