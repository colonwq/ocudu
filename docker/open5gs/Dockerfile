#
# Copyright 2013-2025 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Build args: OS (fedora|ubuntu, default fedora), OS_VERSION (default 43)

ARG OS=fedora
ARG OS_VERSION=43
FROM ${OS}:${OS_VERSION} AS base

# Re-declare so they are available in RUN (ARGs before FROM are not in scope)
ARG OS
ARG OS_VERSION
ARG MONGO_MAJOR_VERSION=6

ENV PYTHONBUFFERED=1

# 1) MongoDB repo + 2) Install all build/runtime packages (OS-specific)
RUN if [ "$OS" = "ubuntu" ]; then \
    apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && update-ca-certificates \
    && curl -fsSL "https://www.mongodb.org/static/pgp/server-${MONGO_MAJOR_VERSION}.0.asc" \
       | gpg --dearmor -o /usr/share/keyrings/mongodb-server-${MONGO_MAJOR_VERSION}.0.gpg \
    && echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${MONGO_MAJOR_VERSION}.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME)/mongodb-org/${MONGO_MAJOR_VERSION}.0 multiverse" \
       | tee /etc/apt/sources.list.d/mongodb-org-${MONGO_MAJOR_VERSION}.0.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    bison \
    build-essential \
    cmake \
    flex \
    gdb \
    gettext \
    git \
    iperf3 \
    iproute2 \
    iptables \
    iputils-ping \
    libcurl4-openssl-dev \
    libgcrypt-dev \
    libgnutls28-dev \
    libidn2-dev \
    libmicrohttpd-dev \
    libmongoc-dev \
    libnghttp2-dev \
    libsctp-dev \
    libssl-dev \
    libtalloc-dev \
    libtins-dev \
    libyaml-cpp-dev \
    meson \
    mongodb-org \
    netcat-openbsd \
    ninja-build \
    nodejs \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    && rm -rf /var/lib/apt/lists/*; \
  else \
    curl -sL -o /etc/pki/rpm-gpg/RPM-GPG-KEY-mongodb \
      "https://www.mongodb.org/static/pgp/server-${MONGO_MAJOR_VERSION}.0.asc" \
    && echo "[mongodb-org-${MONGO_MAJOR_VERSION}.0]" > /etc/yum.repos.d/mongodb-org.repo \
    && echo "name=MongoDB Repository" >> /etc/yum.repos.d/mongodb-org.repo \
    && echo "baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/${MONGO_MAJOR_VERSION}.0/x86_64/" >> /etc/yum.repos.d/mongodb-org.repo \
    && echo "gpgcheck=1" >> /etc/yum.repos.d/mongodb-org.repo \
    && echo "enabled=1" >> /etc/yum.repos.d/mongodb-org.repo \
    && echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mongodb" >> /etc/yum.repos.d/mongodb-org.repo \
    && dnf install -y \
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
    && dnf clean all; \
  fi

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
