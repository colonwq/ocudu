#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#

#
# This script will install OCUDU dependencies for RHEL/UBI
#
# Run like this: ./install_rhel_dependencies.sh [<mode>]
# E.g.: ./install_rhel_dependencies
# E.g.: ./install_rhel_dependencies build
# E.g.: ./install_rhel_dependencies run
# E.g.: ./install_rhel_dependencies extra
# E.g.: ./install_rhel_dependencies all
#

set -e

# Check number of args
if [ $# != 0 ] && [ $# != 1 ]; then
    echo >&2 "Illegal number of parameters"
    echo >&2 "Run like this: \"./install_rhel_dependencies.sh [<mode>]\" where mode could be: build, run, extra and all"
    echo >&2 "If mode is not specified, all dependencies will be installed"
    exit 1
fi

mode="${1:-all}"
# shellcheck source=/dev/null
. /etc/os-release

echo "== Installing RHEL OCUDU dependencies, mode $mode =="

script_dir="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"

if [[ "$ID" != "rhel" ]]; then
    echo "OS $ID not supported (this script is for RHEL/UBI only)"
    exit 1
fi

# UBI 10 / RHEL 10: optional subscription-manager (BuildKit secret); see with_rhsm_rhel10.sh
if [[ "${VERSION_ID:-0}" == 10* ]]; then
    export RHSM_SECRET_FILE="${RHSM_SECRET_FILE:-/run/secrets/rhsm_build_creds}"
    bash "$script_dir/with_rhsm_rhel10.sh" bash -c ':'
    if command -v subscription-manager >/dev/null 2>&1 && subscription-manager identity >/dev/null 2>&1; then
        export RHSM_USING_SUBSCRIPTION=1
    fi
fi

# UBI 10 / RHEL 10: enable CodeReady Builder (dev packages); EL10 uses system gcc (no gcc-toolset)
if [[ "${VERSION_ID:-0}" == 10* ]]; then
    # CodeReady Builder: either from subscription-manager or from the public UBI CDN (no subscription).
    if [[ "${RHSM_USING_SUBSCRIPTION:-0}" != "1" ]]; then
        printf '[ubi-10-codeready-builder]\nname=Red Hat Universal Base Image 10 - CodeReady Builder\nbaseurl=https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi10/10/$basearch/codeready-builder/os\nenabled=1\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release' > /etc/yum.repos.d/ubi10-crb.repo
    fi
    # EPEL 10 for gtest-devel, yaml-cpp-devel, mbedtls-devel, etc.
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
    packages=()
    if [[ "$mode" == "all" || "$mode" == "build" ]]; then
        packages+=(clang cmake fftw-devel git gtest-devel lksctp-tools-devel mbedtls-devel yaml-cpp-devel)
    fi
    if [[ "$mode" == "all" || "$mode" == "run" ]]; then
        packages+=(curl fftw-devel gtest-devel lksctp-tools-devel mbedtls-devel chrony yaml-cpp-devel)
    fi
    if [[ "$mode" == "all" || "$mode" == "extra" ]]; then
        packages+=(boost-devel cppzmq-devel libusb1-devel numactl-devel)
    fi
    if [[ ${#packages[@]} -gt 0 ]]; then
        dnf -y install "${packages[@]}" && dnf clean all
    fi
else
    packages=()
    if [[ "$mode" == "all" || "$mode" == "build" ]]; then
        packages+=(clang cmake fftw-devel gcc-toolset-11 gcc-toolset-11-gcc-c++ gcc-toolset-12-libatomic-devel git lksctp-tools-devel mbedtls-devel which yaml-cpp-devel)
    fi
    if [[ "$mode" == "all" || "$mode" == "run" ]]; then
        packages+=(curl fftw-devel gcc-toolset-12-libatomic-devel lksctp-tools-devel mbedtls-devel chrony yaml-cpp-devel)
    fi
    if [[ "$mode" == "all" || "$mode" == "extra" ]]; then
        packages+=(boost-devel cppzmq-devel libusb1-devel numactl-devel)
    fi
    if [[ ${#packages[@]} -gt 0 ]]; then
        dnf -y install "${packages[@]}" && dnf clean all
    fi
fi
