#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Install UHD dependencies for Arch Linux. Usage: install_uhd_arch_dependencies.sh [<mode>]
# Mode: build | run | all (default)
#

set -e

mode="${1:-all}"

if [[ "$mode" == "all" || "$mode" == "build" ]]; then
    pacman -Syu --noconfirm cmake base-devel boost libusb \
        python-mako python-numpy python-setuptools python-requests pkgconf
fi
if [[ "$mode" == "all" || "$mode" == "run" ]]; then
    pacman -Syu --noconfirm uhd boost libusb python-requests ncurses
    uhd_images_downloader
fi
