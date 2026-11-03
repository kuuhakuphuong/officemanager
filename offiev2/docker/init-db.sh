#!/bin/bash
# ==============================================================================
# Khoi tao & nap toan bo CSDL MySQL tren Docker (chay trong container db-init)
#   1. Cho 3 server MySQL san sang (central, site2, site3).
#   2. Node trung tam (mysql-central): QLToaNha_BCNF (18 bang + seed + trigger + TV4)
#      va manh site 1 (QLToaNha_Site1) = chi nhanh trung tam TN01.
#   3. Site 2 va site 3 nhan manh ngang tu trung tam: tam thoi sao chep QLToaNha_BCNF
#      sang server cua site, lap manh roi xoa ban sao. Moi site chi giu du lieu cua
#      toa nha cua minh (TN02/TN03) theo template 01_TaoSite_Template.
# Chay lai an toan: neu QLToaNha_BCNF da ton tai tren node trung tam thi bo qua nap goc.
# ==============================================================================
set -eo pipefail

echo "======================================================"
echo "    KHOI TAO CO SO DU LIEU MYSQL (DOCKER COMPOSE)      "
echo "======================================================"

PASSWORD="${MYSQL_ROOT_PASSWORD:?Thieu MYSQL_ROOT_PASSWORD}"
export MYSQL_PWD="$PASSWORD"  # mysql/mysqladmin/mysqldump doc mat khau tu bien nay (khong de lo tren dong lenh)
CENTRAL_HOST="${MYSQL_CENTRAL_HOST:-mysql-central}"
SITE2_HOST="${MYSQL_SITE2_HOST:-mysql-site2}"
SITE3_HOST="${MYSQL_SITE3_HOST:-mysql-site3}"
ROOT="/app/database"
WORK="$(mktemp -d)"

mysql_on() { mysql -h "$1" -P 3306 -uroot  --default-character-set=utf8mb4 "${@:2}"; }

wait_for() {
    local host="$1" count=0
    until mysqladmin -h "$host" -P 3306 -uroot  ping --silent >/dev/null 2>&1; do
        count=$((count + 1))
        if [ "$count" -ge 90 ]; then
            echo "[ERROR] Het thoi gian cho MySQL tai $host"
            exit 1
        fi
        echo "  [Doi $count/90] Cho MySQL tai $host san sang..."
        sleep 2
    done
    echo "[OK] MySQL $host san sang"
}

wait_for "$CENTRAL_HOST"
wait_for "$SITE2_HOST"
wait_for "$SITE3_HOST"

if mysql_on "$CENTRAL_HOST" -N -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = 'QLToaNha_BCNF'" | grep -q QLToaNha_BCNF; then
    echo "[INFO] QLToaNha_BCNF da ton tai tren $CENTRAL_HOST. Bo qua nap CSDL trung tam."
else
    echo "1/6 [TV3] Tao CSDL & 18 bang BCNF"
    mysql_on "$CENTRAL_HOST" < "$ROOT/schema/01_CreateSchema_TV3_NguyenThiLanAnh.sql"
    echo "2/6 [TV3] Nap du lieu mau 2 thang"
    mysql_on "$CENTRAL_HOST" < "$ROOT/schema/02_InsertSeedData_TV3_NguyenThiLanAnh.sql"
    echo "3/6 [TV3] Kiem tra rang buoc"
    mysql_on "$CENTRAL_HOST" < "$ROOT/schema/03_Validate_TV3_NguyenThiLanAnh.sql"
    echo "4/6 [TV5] Cai dat 6 quy tac trigger (10 trigger vat ly)"
    mysql_on "$CENTRAL_HOST" QLToaNha_BCNF < "$ROOT/triggers/05_Phan5_Triggers_TV5_KhucTuanAnh.sql"
    echo "5/6 [TV4] Cai dat procedure giao dich"
    mysql_on "$CENTRAL_HOST" QLToaNha_BCNF < "$ROOT/transactions/00_TaoKieuDuLieu_TV4_VuTrungHieu.sql"
    mysql_on "$CENTRAL_HOST" QLToaNha_BCNF < "$ROOT/transactions/02_KiemTraTuongThich_TV4_VuTrungHieu.sql"
    mysql_on "$CENTRAL_HOST" QLToaNha_BCNF < "$ROOT/transactions/03_Transactions_TV4_VuTrungHieu.sql"
fi

echo "6/6 [TV7] Phan manh 3 site"
# Site 1 (trung tam): manh ngang TN01 + manh doc (ho so thue, tien luong) ngay tren node trung tam.
sed -e "s/__SITE_DB__/QLToaNha_Site1/g" -e "s/__TOA_NHA__/TN01/g" "$ROOT/distributed/01_TaoSite_Template_TV7_BuiDoanQuangHuy.sql" \
    | mysql_on "$CENTRAL_HOST"
sed -e "s/__SITE_DB__/QLToaNha_Site1/g" "$ROOT/distributed/02_TrungTam_Extras_TV7_BuiDoanQuangHuy.sql" \
    | mysql_on "$CENTRAL_HOST"

# Site 2 va site 3: sao chep tam CSDL trung tam roi lap manh tren server cua site.
for site in "2:$SITE2_HOST:TN02" "3:$SITE3_HOST:TN03"; do
    IFS=':' read -r num host building <<< "$site"
    echo "  [Site $num] sao chep tam tu $CENTRAL_HOST sang $host"
    mysqldump -h "$CENTRAL_HOST" -uroot  --no-tablespaces --skip-triggers --routines=false \
        --single-transaction QLToaNha_BCNF > "$WORK/central_$num.sql"
    mysql_on "$host" -e "DROP DATABASE IF EXISTS QLToaNha_BCNF; CREATE DATABASE QLToaNha_BCNF CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_as_ci"
    mysql_on "$host" QLToaNha_BCNF < "$WORK/central_$num.sql"
    sed -e "s/__SITE_DB__/QLToaNha_Site$num/g" -e "s/__TOA_NHA__/$building/g" "$ROOT/distributed/01_TaoSite_Template_TV7_BuiDoanQuangHuy.sql" \
        | mysql_on "$host"
    mysql_on "$host" -e "DROP DATABASE QLToaNha_BCNF"
    rm -f "$WORK/central_$num.sql"
done

rm -rf "$WORK"

echo "======================================================"
echo "[SUCCESS] KHOI TAO CSDL MYSQL THANH CONG (trung tam + 3 site)"
echo "======================================================"
exit 0
