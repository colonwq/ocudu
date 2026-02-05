#
# Copyright 2013-2025 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#

ARG OS_VERSION=43
FROM fedora:${OS_VERSION} AS base

ENV PYTHONBUFFERED=1

# 1) Create MongoDB repo and GPG key before the single dnf install
ARG MONGO_MAJOR_VERSION=6
RUN curl -sL -o /etc/pki/rpm-gpg/RPM-GPG-KEY-mongodb \
    "https://www.mongodb.org/static/pgp/server-${MONGO_MAJOR_VERSION}.0.asc" \
    && echo "[mongodb-org-${MONGO_MAJOR_VERSION}.0]" > /etc/yum.repos.d/mongodb-org.repo \
    && echo "name=MongoDB Repository" >> /etc/yum.repos.d/mongodb-org.repo \
    && echo "baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/${MONGO_MAJOR_VERSION}.0/x86_64/" >> /etc/yum.repos.d/mongodb-org.repo \
    && echo "gpgcheck=1" >> /etc/yum.repos.d/mongodb-org.repo \
    && echo "enabled=1" >> /etc/yum.repos.d/mongodb-org.repo \
    && echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mongodb" >> /etc/yum.repos.d/mongodb-org.repo

# 2) Single dnf install for all packages (base image has curl for the step above)
RUN dnf install -y \
    bison \
    cmake \
    curl \
    dnf-plugins-core \
    flex \
    gcc \
    gcc-c++ \
    gdb \
    gettext \
    git \
    gnutls-devel \
    iperf3 \
    iproute \
    iptables \
    iputils \
    libcurl-devel \
    libgcrypt-devel \
    libidn-devel \
    libmicrohttpd-devel \
    libnghttp2-devel \
    libtalloc-devel \
    libtins-devel \
    libyaml-devel \
    lksctp-tools-devel \
    make \
    meson \
    mongo-c-driver-devel \
    mongodb-org \
    ninja-build \
    nmap-ncat \
    nodejs \
    openssl-devel \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    && dnf clean all

# 3) Python pip install
RUN python3 -m pip install click ipaddress pyroute2 pymongo python-iptables

# 4) Build open5gs
ARG OPEN5GS_VERSION=v2.7.5
RUN echo $OPEN5GS_VERSION > ./open5gsversion
# get latest open5gs tag (must be stored in a file, because docker does not allow to use the return value directly)
# RUN git ls-remote --tags https://github.com/open5gs/open5gs | sort -t '/' -k 3 -V | awk -F/ '{ print $3 }' | awk '!/\^\{\}/' | tail -n 1 > ./open5gsversion

ARG NUM_JOBS=""
RUN if [ -z "$NUM_JOBS" ]; then NUM_JOBS=$(nproc); fi && \
    git clone --depth 1 --branch $(cat ./open5gsversion) https://github.com/open5gs/open5gs open5gs\
    && cd open5gs \
    && meson build --prefix=`pwd`/install \
    && ninja -j ${NUM_JOBS} -C build \
    && cd build \
    && ninja install

# On Fedora/RHEL meson installs to lib64; config expects lib/x86_64-linux-gnu/freeDiameter
RUN if [ -d /open5gs/install/lib64/freeDiameter ]; then \
      mkdir -p /open5gs/install/lib/x86_64-linux-gnu /open5gs/install/lib/aarch64-linux-gnu && \
      cp -a /open5gs/install/lib64/freeDiameter /open5gs/install/lib/x86_64-linux-gnu/ && \
      cp -a /open5gs/install/lib64/freeDiameter /open5gs/install/lib/aarch64-linux-gnu/; \
    fi

# 5) npm install for webui
RUN cd open5gs/webui && npm ci --no-optional

#############################
# Final stage: open5gs run  #
#############################
FROM base AS open5gs

WORKDIR /open5gs
COPY open5gs-5gc.yml open5gs-5gc.yml.in
# The wildcard for the subscriber_db.csv tries to copy "subscriber_db.csv" but will not fail if the file doesn't exist
COPY open5gs_entrypoint.sh add_users.py setup_tun.py subscriber_db.cs[v] ./

ENV PATH="${PATH}:/open5gs/build/tests/app/"

ENTRYPOINT [ "./open5gs_entrypoint.sh" ]
