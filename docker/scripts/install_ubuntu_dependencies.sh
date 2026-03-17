#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Install OCUDU dependencies for Debian/Ubuntu. Usage: install_ubuntu_dependencies.sh [<mode>]
# Mode: build | run | extra | all (default)
#

set -e

mode="${1:-all}"

if [[ "$mode" == "all" || "$mode" == "build" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
        clang cmake gcc g++ git make pkg-config libfftw3-dev libmbedtls-dev libsctp-dev libyaml-cpp-dev libgtest-dev && \
        apt-get clean && rm -rf /var/lib/apt/lists/*
fi
if [[ "$mode" == "all" || "$mode" == "run" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
        curl libfftw3-dev libmbedtls-dev libsctp-dev libyaml-cpp-dev libgtest-dev ntpdate && \
        apt-get clean && rm -rf /var/lib/apt/lists/*
fi
if [[ "$mode" == "all" || "$mode" == "extra" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
        libzmq3-dev libuhd-dev uhd-host libboost-program-options-dev libdpdk-dev libelf-dev libdwarf-dev libdw-dev && \
        apt-get clean && rm -rf /var/lib/apt/lists/*

    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends gpg gpg-agent wget && \
            apt-get clean && rm -rf /var/lib/apt/lists/*
        wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
        echo "deb [trusted=yes] https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list
        DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            intel-oneapi-mkl-core-devel-2025.0 \
            libomp-dev && \
            apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
    else
        DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends wget && \
            apt-get clean && rm -rf /var/lib/apt/lists/*
        pushd /tmp
        wget https://developer.arm.com/-/cdn-downloads/permalink/Arm-Performance-Libraries/Version_24.10/arm-performance-libraries_24.10_deb_gcc.tar
        tar -xf arm-performance-libraries_24.10_deb_gcc.tar
        rm -f arm-performance-libraries_24.10_deb_gcc.tar
        cd arm-performance-libraries_24.10_deb/
        ./arm-performance-libraries_24.10_deb.sh --accept
        popd
        rm -Rf /tmp/arm-performance-libraries_24.10_deb/
        DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends environment-modules && \
            apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
        source /usr/share/modules/init/bash
        export MODULEPATH=$MODULEPATH:/opt/arm/modulefiles
        module avail
        module load armpl/24.10.0_gcc
    fi
fi
