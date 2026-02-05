#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#

#
# This script will install ocudu dependencies
#
# Run like this: ./install_dependencies.sh [<mode>]
# E.g.: ./install_dependencies
# E.g.: ./install_dependencies build
# E.g.: ./install_dependencies run
# E.g.: ./install_dependencies extra
#

set -e

main() {

    # Check number of args
    if [ $# != 0 ] && [ $# != 1 ]; then
        echo >&2 "Illegal number of parameters"
        echo >&2 "Run like this: \"./install_dependencies.sh [<mode>]\" where mode could be: build, run and extra"
        echo >&2 "If mode is not specified, all dependencies will be installed"
        exit 1
    fi

    local mode="${1:-all}"

    . /etc/os-release

    echo "== Installing OCUDU dependencies, mode $mode =="

    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
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

    elif [[ "$ID" == "arch" ]]; then
        if [[ "$mode" == "all" || "$mode" == "build" ]]; then
            pacman -Syu --noconfirm cmake make base-devel fftw mbedtls yaml-cpp lksctp-tools gtest pkgconf
        fi
        if [[ "$mode" == "all" || "$mode" == "run" ]]; then
            pacman -Syu --noconfirm fftw mbedtls yaml-cpp lksctp-tools gtest
        fi
        if [[ "$mode" == "all" || "$mode" == "extra" ]]; then
            pacman -Syu --noconfirm zeromq libuhd boost dpdk libelf libdwarf elfutils
        fi

    elif [[ "$ID" == "rhel" ]]; then
        packages=()
        if [[ "$mode" == "all" || "$mode" == "build" ]]; then
            packages+=(clang cmake fftw-devel gcc-toolset-11 gcc-toolset-11-gcc-c++ gcc-toolset-12-libatomic-devel git lksctp-tools-devel mbedtls-devel which yaml-cpp-devel)
        fi
        if [[ "$mode" == "all" || "$mode" == "run" ]]; then
            packages+=(curl fftw-devel gcc-toolset-12-libatomic-devel lksctp-tools-devel mbedtls-devel ntpdate yaml-cpp-devel)
        fi
        if [[ "$mode" == "all" || "$mode" == "extra" ]]; then
            packages+=(boost-devel cppzmq-devel libusb1-devel numactl-devel)
        fi
        if [[ ${#packages[@]} -gt 0 ]]; then
            dnf -y install "${packages[@]}" && dnf clean all
        fi

    elif [[ "$ID" == "fedora" ]]; then
        packages=()
        if [[ "$mode" == "all" || "$mode" == "build" ]]; then
            packages+=(clang cmake fftw-devel git gtest-devel lksctp-tools-devel mbedtls-devel which yaml-cpp-devel)
        fi
        if [[ "$mode" == "all" || "$mode" == "run" ]]; then
            packages+=(curl fftw-devel gtest-devel lksctp-tools-devel mbedtls-devel ntpdate yaml-cpp-devel)
        fi
        if [[ "$mode" == "all" || "$mode" == "extra" ]]; then
            packages+=(boost-devel cppzmq-devel libusb1-devel numactl-devel)
        fi
        if [[ ${#packages[@]} -gt 0 ]]; then
            dnf -y install "${packages[@]}" && dnf clean all
        fi

    else
        echo "OS $ID not supported"
        exit 1
    fi

}

main "$@"
