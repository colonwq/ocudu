#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Install UHD dependencies for RHEL/UBI. Usage: install_uhd_rhel_dependencies.sh [<mode>]
# Mode: build | run | all (default)
#

set -e

mode="${1:-all}"
script_dir="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
# shellcheck source=/dev/null
. /etc/os-release

if [[ "${VERSION_ID:-0}" == 10* ]]; then
    export RHSM_SECRET_FILE="${RHSM_SECRET_FILE:-/run/secrets/rhsm_build_creds}"
    bash "$script_dir/with_rhsm_rhel10.sh" bash -c ':'
fi

if [[ "$mode" == "all" || "$mode" == "build" ]]; then
    dnf -y install cmake gcc-c++ pkg-config boost-devel libusb1-devel \
        python3-mako python3-numpy python3-setuptools python3-requests
fi
# Run mode: UHD binaries come from build_uhd.sh / image; only install shared libs and fetch images.
if [[ "$mode" == "all" || "$mode" == "run" ]]; then
    dnf -y install boost-devel ncurses-devel libusb1 libusb1-devel python3-requests
    uhd_images_downloader
fi
