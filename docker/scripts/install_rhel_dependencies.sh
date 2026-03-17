#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Install OCUDU dependencies for RHEL/UBI. Usage: install_rhel_dependencies.sh [<mode>]
# Mode: build | run | extra | all (default)
#

set -e
set -x

mode="${1:-all}"
# shellcheck source=/dev/null
. /etc/os-release

# UBI 10 / RHEL 10: enable CodeReady Builder (dev packages); EL10 uses system gcc (no gcc-toolset)
if [[ "${VERSION_ID:-0}" == 10* ]]; then
    #dnf -y install 'dnf-command(config-manager)'
    #dnf config-manager --set-enabled crb || true
    # Force-create the UBI 10 CRB repo (no subscription required)
#    cat << 'EOF' > /etc/yum.repos.d/ubi10-crb.repo
#[ubi-10-codeready-builder]
#name=Red Hat Universal Base Image 10 - CodeReady Builder
#baseurl=https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi10/10/$basearch/codeready-builder/os
#enabled=1
#gpgcheck=1
#gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
#EOF
    # EPEL 10 for gtest-devel, yaml-cpp-devel, mbedtls-devel, etc.
    #dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
    echo "XXX CRB 10 enable"
    printf '[ubi-10-codeready-builder]\nname=Red Hat Universal Base Image 10 - CodeReady Builder\nbaseurl=https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi10/10/$basearch/codeready-builder/os\nenabled=1\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release' > /etc/yum.repos.d/ubi10-crb.repo
    echo "XXX EPEL 10 install"
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
    #echo "XXX CRB 10 install"
    #printf '[ubi-10-codeready-builder]\nname=Red Hat Universal Base Image 10 - CodeReady Builder\nbaseurl=https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi10/10/$basearch/codeready-builder/os\nenabled=1\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release' > /etc/yum.repos.d/ubi10-crb.repo
    #dnf update 
    echo "XXX List repos"
    dnf repolist
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
