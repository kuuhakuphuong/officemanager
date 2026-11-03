#!/bin/bash
# ==============================================================================
# Entrypoint chung cho cum MongoDB phan manh (sharded cluster):
#   ROLE=config  -> config server (replica set cfgRS, port 27019)
#   ROLE=shard1|shard2|shard3 -> shard (replica set shardNRS, port 27018)
#   ROLE=mongos  -> router (port 27017): them shard, tao user admin, nap du lieu,
#                   bat sharding + zone theo toa nha. Khi xong ghi file /tmp/mongo-cluster-ready.
# Moi node tu khoi tao replica set qua localhost exception (chua co user), nen
# khong can container khoi tao rieng.
# ==============================================================================
set -eo pipefail

ROLE="$1"
KEYFILE=/etc/mongo/keyfile
ADMIN_USER="${MONGO_INITDB_ROOT_USERNAME:-admin}"
ADMIN_PASS="${MONGO_INITDB_ROOT_PASSWORD:?Thieu MONGO_INITDB_ROOT_PASSWORD}"
READY_FILE=/tmp/mongo-cluster-ready
rm -f "$READY_FILE"

wait_port() {
    local port="$1" count=0
    until mongosh --quiet --port "$port" --eval 'db.adminCommand({ ping: 1 }).ok' >/dev/null 2>&1; do
        count=$((count + 1))
        [ "$count" -ge 60 ] && { echo "[ERROR] Cong $port khong len"; exit 1; }
        sleep 2
    done
}

wait_primary() {
    local host="$1" port="$2" count=0
    until mongosh --quiet --host "$host" --port "$port" --eval 'db.hello().isWritablePrimary' 2>/dev/null | grep -q true; do
        count=$((count + 1))
        [ "$count" -ge 90 ] && { echo "[ERROR] Khong tim thay primary tai $host:$port"; exit 1; }
        echo "  [doi] $host:$port chua co primary ($count/90)"
        sleep 2
    done
}

# Khoi tao replica set neu chua co (chay tren localhost cua chinh node).
init_replica_set() {
    local port="$1" config="$2"
    mongosh --quiet --port "$port" --eval "
        try { rs.status(); print('replica set da khoi tao'); }
        catch (e) { rs.initiate($config); print('da khoi tao replica set'); }"
}

case "$ROLE" in
    config)
        mongod --configsvr --replSet cfgRS --port 27019 --bind_ip_all --keyFile "$KEYFILE" --dbpath /data/db &
        wait_port 27019
        init_replica_set 27019 '{ _id: "cfgRS", configsvr: true, members: [{ _id: 0, host: "mongo-config:27019" }] }'
        wait_primary localhost 27019
        # User quan tri tao o config server (mongod: localhost exception con hieu luc).
        # mongos xac thuc bang user nay; localhost exception khong ap dung cho mongos khi bat keyfile.
        mongosh --quiet --port 27019 --eval "
            try {
                db.getSiblingDB('admin').createUser({ user: '${ADMIN_USER}', pwd: '${ADMIN_PASS}', roles: ['root'] });
                print('da tao user ${ADMIN_USER} tren config server');
            } catch (e) { print('[info] user quan tri co the da ton tai: ' + e.message); }" || true
        echo "[OK] config server san sang"
        wait
        ;;

    shard1|shard2|shard3)
        n="${ROLE#shard}"
        mongod --shardsvr --replSet "shard${n}RS" --port 27018 --bind_ip_all --keyFile "$KEYFILE" --dbpath /data/db &
        wait_port 27018
        init_replica_set 27018 "{ _id: \"shard${n}RS\", members: [{ _id: 0, host: \"mongo-shard${n}:27018\" }] }"
        wait_primary localhost 27018
        echo "[OK] shard${n}RS san sang"
        wait
        ;;

    mongos)
        mongos --configdb cfgRS/mongo-config:27019 --bind_ip_all --port 27017 --keyFile "$KEYFILE" &
        MONGOS_PID=$!
        wait_port 27017
        wait_primary mongo-config 27019

        AUTH_URI="mongodb://${ADMIN_USER}:${ADMIN_PASS}@127.0.0.1:27017/?authSource=admin"

        # 1. Them 3 shard (idempotent, thu lai neu shard chua san sang).
        for n in 1 2 3; do
            count=0
            until mongosh "$AUTH_URI" --quiet --eval "
                if (!db.getSiblingDB('config').shards.findOne({ _id: 'shard${n}RS' })) {
                    sh.addShard('shard${n}RS/mongo-shard${n}:27018');
                }
                print('shard${n}RS ok');" 2>/dev/null | grep -q 'ok'; do
                count=$((count + 1))
                [ "$count" -ge 30 ] && { echo "[ERROR] Khong them duoc shard${n}RS"; exit 1; }
                sleep 3
            done
        done

        # 2. Nap du lieu mau (06_MongoDB) bang user quan tri, truoc khi bat sharding.
        mongosh "$AUTH_URI" --quiet --file /docker/init-mongo.js

        # 3. Bat sharding theo maToaNha (tat ca collection deu co truong nay) va gan zone theo site.
        mongosh "$AUTH_URI" --quiet --eval "
            const dbName = 'QuanLyToaNha';
            const dbx = db.getSiblingDB(dbName);
            ['toanha', 'hopdong_thue', 'nhatky_dichvu'].forEach((c) => {
                try { dbx[c].createIndex({ maToaNha: 1 }); } catch (e) { print(e.message); }
            });
            try { sh.enableSharding(dbName); } catch (e) { print(e.message); }
            ['toanha', 'hopdong_thue', 'nhatky_dichvu'].forEach((c) => {
                try { sh.shardCollection(dbName + '.' + c, { maToaNha: 1 }); print('sharded ' + c); }
                catch (e) { print('shardCollection ' + c + ': ' + e.message); }
            });
            const zones = [
                { shard: 'shard1RS', tag: 'TN01', min: 'TN01', max: 'TN02' },
                { shard: 'shard2RS', tag: 'TN02', min: 'TN02', max: 'TN03' },
                { shard: 'shard3RS', tag: 'TN03', min: 'TN03', max: MaxKey() }
            ];
            zones.forEach((z) => {
                try { sh.addShardTag(z.shard, z.tag); } catch (e) { print(e.message); }
                ['toanha', 'hopdong_thue', 'nhatky_dichvu'].forEach((c) => {
                    const range = { min: { maToaNha: z.min }, max: { maToaNha: z.max } };
                    try { sh.updateZoneKeyRange(dbName + '.' + c, range.min, range.max, z.tag); }
                    catch (e) { print('zone ' + c + ' ' + z.tag + ': ' + e.message); }
                });
            });
            print('cau hinh sharding + zone xong');"

        touch "$READY_FILE"
        echo "[OK] MongoDB sharded cluster san sang (mongos cong 27017)"
        wait "$MONGOS_PID"
        ;;

    *)
        echo "ROLE khong hop le: $ROLE (config|shard1|shard2|shard3|mongos)"
        exit 1
        ;;
esac
