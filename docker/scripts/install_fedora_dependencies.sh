#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Install OCUDU dependencies for Fedora/CentOS Stream. Usage: install_fedora_dependencies.sh [<mode>]
# Mode: build | run | extra | all (default)
#

set -e

mode="${1:-all}"
# shellcheck source=/dev/null
. /etc/os-release

# CentOS Stream (e.g. 10) needs CRB + EPEL for gtest-devel, mbedtls-devel, yaml-cpp-devel
if [[ "$ID" == "centos" ]]; then
    dnf -y install 'dnf-command(config-manager)'
    dnf config-manager --set-enabled crb || true
    dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
fi
packages=()
if [[ "$mode" == "all" || "$mode" == "build" ]]; then
    packages+=(clang cmake fftw-devel git gtest-devel lksctp-tools-devel mbedtls-devel which yaml-cpp-devel)
fi
if [[ "$mode" == "all" || "$mode" == "run" ]]; then
    # EL10 (CentOS Stream 10, RHEL 10) replaced ntpdate with chrony
    if [[ "$ID" == "centos" ]]; then
        packages+=(curl fftw-devel gtest-devel lksctp-tools-devel mbedtls-devel chrony yaml-cpp-devel)
    else
        packages+=(curl fftw-devel gtest-devel lksctp-tools-devel mbedtls-devel ntpdate yaml-cpp-devel)
    fi
fi
if [[ "$mode" == "all" || "$mode" == "extra" ]]; then
    packages+=(boost-devel cppzmq-devel libusb1-devel numactl-devel)
fi
if [[ ${#packages[@]} -gt 0 ]]; then
    dnf -y install "${packages[@]}" && dnf clean all
fi
