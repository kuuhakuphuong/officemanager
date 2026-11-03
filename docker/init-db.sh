#!/bin/bash
set -eo pipefail

echo "======================================================"
echo "    KHOI TAO CO SO DU LIEU SQL SERVER (LINUX/DOCKER)   "
echo "======================================================"

DB_SERVER="${DB_SERVER:-db}"
DB_PORT="${DB_PORT:-1433}"
MSSQL_SA_PASSWORD="${MSSQL_SA_PASSWORD:-Password123!}"

SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
if [ ! -f "$SQLCMD" ]; then
    SQLCMD="/opt/mssql-tools/bin/sqlcmd"
fi

if [ ! -f "$SQLCMD" ]; then
    echo "[ERROR] Khong tim thay sqlcmd trong container!"
    exit 1
fi

echo "[INFO] Su dung sqlcmd tai: $SQLCMD"
echo "[INFO] Dang cho SQL Server tai $DB_SERVER:$DB_PORT san sang..."

MAX_RETRIES=60
COUNT=0
until $SQLCMD -S "$DB_SERVER,$DB_PORT" -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" > /dev/null 2>&1
do
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "[ERROR] Het thoi gian cho SQL Server ket noi sau $MAX_RETRIES lan thu."
        exit 1
    fi
    echo "  [Retrying $COUNT/$MAX_RETRIES] Cho SQL Server khoi dong... (2s)"
    sleep 2
done

echo "[SUCCESS] SQL Server da ket noi thanh cong!"

# Kiem tra database trung tam da ton tai chua
DB_EXISTS=$($SQLCMD -S "$DB_SERVER,$DB_PORT" -U sa -P "$MSSQL_SA_PASSWORD" -C -h -1 -W -Q "SET NOCOUNT ON; SELECT DB_ID(N'QLToaNha_BCNF');")

if [ -n "$DB_EXISTS" ] && [ "$DB_EXISTS" != "NULL" ]; then
    echo "[INFO] Database 'QLToaNha_BCNF' da ton tai tren volume luu tru. Bo qua buoc nap du lieu ban dau."
    echo "[SUCCESS] He thong san sang cho Web App."
    exit 0
fi

echo "[INFO] Bat dau qua trinh khoi tao CSDL 18 bang BCNF..."

F_SCHEMA="/app/database/schema/01_CreateSchema.sql"
F_SEED="/app/database/schema/02_InsertSeedData.sql"
F_VALIDATE="/app/database/schema/03_Validate.sql"
F_TRIGGERS="/app/database/triggers/05_Phan5_Triggers.sql"
F_TYPES="/app/database/transactions/00_TaoKieuDuLieu.sql"
F_TRANS="/app/database/transactions/03_Transactions.sql"

F_SITE1="/app/database/distributed/01_NapDB_Site1_TrungTam.sql"
F_SITE2="/app/database/distributed/02_NapDB_Site2_ChiNhanh2.sql"
F_SITE3="/app/database/distributed/03_NapDB_Site3_ChiNhanh3.sql"

echo "1/7 [TV3] Tao CSDL & 18 bang BCNF: $F_SCHEMA"
$SQLCMD -S "$DB_SERVER,$DB_PORT" -U sa -P "$MSSQL_SA_PASSWORD" -C -i "$F_SCHEMA"

echo "2/7 [TV3] Nap du lieu mau Seed 2 thang: $F_SEED"
$SQLCMD -S "$DB_SERVER,$DB_PORT" -U sa -P "$MSSQL_SA_PASSWORD" -C -i "$F_SEED"

echo "3/7 [TV3] Kiem tra rang buoc Validate: $F_VALIDATE"
$SQLCMD -S "$DB_SERVER,$DB_PORT" -U sa -P "$MSSQL_SA_PASSWORD" -C -i "$F_VALIDATE"

echo "4/7 [TV5] Cai dat 6 Triggers nghiep vu: $F_TRIGGERS"
$SQLCMD -S "$DB_SERVER,$DB_PORT" -U sa -P "$MSSQL_SA_PASSWORD" -C -d QLToaNha_BCNF -i "$F_TRIGGERS"

echo "5/7 [TV4] Cai dat Table Types: $F_TYPES"
$SQLCMD -S "$DB_SERVER,$DB_PORT" -U sa -P "$MSSQL_SA_PASSWORD" -C -d QLToaNha_BCNF -i "$F_TYPES"

echo "6/7 [TV4] Cai dat 5 Stored Procedures Transactions: $F_TRANS"
$SQLCMD -S "$DB_SERVER,$DB_PORT" -U sa -P "$MSSQL_SA_PASSWORD" -C -d QLToaNha_BCNF -i "$F_TRANS"

if [ -f "$F_SITE1" ] && [ -f "$F_SITE2" ] && [ -f "$F_SITE3" ]; then
    echo "7/7 [TV7] Khoi tao 3 Site CSDL Phan tan (QLToaNha_Site1, Site2, Site3)..."
    $SQLCMD -S "$DB_SERVER,$DB_PORT" -U sa -P "$MSSQL_SA_PASSWORD" -C -i "$F_SITE1"
    $SQLCMD -S "$DB_SERVER,$DB_PORT" -U sa -P "$MSSQL_SA_PASSWORD" -C -i "$F_SITE2"
    $SQLCMD -S "$DB_SERVER,$DB_PORT" -U sa -P "$MSSQL_SA_PASSWORD" -C -i "$F_SITE3"
fi

echo "======================================================"
echo "[SUCCESS] KHOI TAO DU LIEU THANH CONG 100%!"
echo "======================================================"
exit 0
