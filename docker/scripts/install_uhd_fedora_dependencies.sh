#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Install UHD dependencies for Fedora/CentOS Stream. Usage: install_uhd_fedora_dependencies.sh [<mode>]
# Mode: build | run | all (default)
#

set -e

mode="${1:-all}"

if [[ "$mode" == "all" || "$mode" == "build" ]]; then
    dnf -y install cmake gcc-c++ pkg-config boost-devel libusb1-devel \
        python3-mako python3-numpy python3-setuptools python3-requests
fi
if [[ "$mode" == "all" || "$mode" == "run" ]]; then
    dnf -y install boost-devel ncurses-devel libusb1 libusb1-devel python3-requests uhd uhd-devel
    uhd_images_downloader
fi
