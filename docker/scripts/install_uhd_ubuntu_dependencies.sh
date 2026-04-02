#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Install UHD dependencies for Debian/Ubuntu. Usage: install_uhd_ubuntu_dependencies.sh [<mode>]
# Mode: build | run | all (default)
#

set -e

mode="${1:-all}"

if [[ "$mode" == "all" || "$mode" == "build" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
        curl apt-transport-https ca-certificates xz-utils \
        cmake build-essential pkg-config \
        libboost-all-dev libusb-1.0-0-dev \
        python3-mako python3-numpy python3-setuptools python3-requests

fi
if [[ "$mode" == "all" || "$mode" == "run" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
        cpufrequtils inetutils-tools libboost-all-dev libncurses5-dev libusb-1.0-0 libusb-1.0-0-dev \
        libusb-dev python3-dev python3-requests &&
        apt-get autoremove && apt-get clean && rm -rf /var/lib/apt/lists/*
    uhd_images_downloader
fi
