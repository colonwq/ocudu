#! /bin/bash

export UE_GATEWAY_IP="${UE_IP_BASE}.1"
export UE_IP_RANGE="${UE_IP_BASE}.0/24"

INSTALL_ARCH=x86_64-linux-gnu
if [ "$(uname -m)" = "aarch64" ]; then
    INSTALL_ARCH="aarch64-linux-gnu"
fi
export INSTALL_ARCH

envsubst < open5gs-5gc.yml.in > open5gs-5gc.yml

# create localhost addresses 127.0.0.2-22 for open5gs entities to bind to
# use secondary addresses on loopback (works in containers without dummy kernel module)
for IP in {2..22}
do
    ip addr add 127.0.0.$IP/8 dev lo 2>/dev/null || true
done

# run mongodb first so it is ready before webui and 5gc
mkdir -p /data/db && mongod --logpath /tmp/mongodb.log --bind_ip 127.0.0.1 &

# wait for mongodb to be available (webui and add_users will need it)
while ! ( nc -zv $MONGODB_IP 27017 2>&1 >/dev/null )
do
    echo waiting for mongodb
    sleep 1
done

# run webui (use DB_URI so it connects to 127.0.0.1, avoiding IPv6 ::1)
export DB_URI="mongodb://${MONGODB_IP}/open5gs"
cd webui && npm run dev &

# setup ogstun and routing (non-fatal: in OpenShift/Kubernetes TUN may not be available)
if ! python3 setup_tun.py --ip_range ${UE_IP_RANGE}; then
    echo "WARNING: Failed to setup ogstun and routing (TUN not available?); continuing without it. UE data plane may not work."
fi

# Add subscriber data to open5gs mongo db
echo "SUBSCRIBER_DB=${SUBSCRIBER_DB}"
python3 add_users.py --mongodb ${MONGODB_IP} --subscriber_data ${SUBSCRIBER_DB}
if [ $? -ne 0 ]
then
    echo "Failed to add subscribers to database"
    exit 1
fi

# Default to 5gc when no args (e.g. OpenShift runs entrypoint with no CMD)
if [ $# -eq 0 ]; then
    set -- 5gc -c open5gs-5gc.yml
fi
if $DEBUG
then
    exec stdbuf -o L gdb -batch -ex=run -ex=bt --args "$@"
else
    exec stdbuf -o L "$@"
fi
