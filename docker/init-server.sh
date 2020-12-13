#!/bin/sh
set -e

POD_IDX=${HOSTNAME##*-};
# export HASH_METHOD="scram-sha-256"
export HASH_METHOD="md5"

# Get the primary IP
export PRIMARY_IP=$(nslookup ${MY_SERVICE_NAME}-server-0.${MY_SERVICE_NAME}.${MY_POD_NAMESPACE}.svc.cluster.local | grep -i 'address:' | grep -v ':53' | awk '{print $2}' | head -n 1);

# Check if the data dir was initiated before
if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    if [ "${POD_IDX}" == "0" ]; then
        echo "${POSTGRES_PASSWORD}" > /tmp/passwd;
        initdb -U postgres --pwfile=/tmp/passwd;

        TMP_IP=$(echo "${MY_POD_IP}" | awk -F"." '{print $1"."$2".0.0"}');
        echo "host    all             postgres        ${TMP_IP}/16         ${HASH_METHOD}" >> ${PGDATA}/pg_hba.conf;
        echo "host    replication     repuser         ${TMP_IP}/16         ${HASH_METHOD}" >> ${PGDATA}/pg_hba.conf;
    else
        echo "${PRIMARY_IP}:*:*:postgres:${POSTGRES_PASSWORD}" > ${HOME}/.pgpass;
        echo "${PRIMARY_IP}:*:*:repuser:${REPUSER_PASSWORD}" >> ${HOME}/.pgpass;
        chmod 0600 ${HOME}/.pgpass

        psql -h ${PRIMARY_IP} -U postgres -w -c "CREATE USER repuser WITH ENCRYPTED PASSWORD '${REPUSER_PASSWORD}' REPLICATION;" || true;
        pg_basebackup -D ${PGDATA} -h ${PRIMARY_IP} -R -X stream -c fast -U repuser -w;
        chmod 0750 ${PGDATA};
    fi
fi

# Fix the config
if [ "${POD_IDX}" == "0" ]; then
    envsubst < /tmp/conf/primary.conf > ${PGDATA}/postgresql.conf;
else
    echo "${PRIMARY_IP}:*:*:repuser:${REPUSER_PASSWORD}" > ${HOME}/.pgpass;
    envsubst < /tmp/conf/standby.conf > ${PGDATA}/postgresql.conf;
    sed -i -e "/primary_conninfo/ s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/${PRIMARY_IP}/" /var/lib/postgresql/data/postgresql.auto.conf;
fi