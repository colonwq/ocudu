#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Install OCUDU dependencies for Arch Linux. Usage: install_arch_dependencies.sh [<mode>]
# Mode: build | run | extra | all (default)
#

set -e

mode="${1:-all}"

if [[ "$mode" == "all" || "$mode" == "build" ]]; then
    pacman -Syu --noconfirm cmake make base-devel fftw mbedtls yaml-cpp lksctp-tools gtest pkgconf
fi
if [[ "$mode" == "all" || "$mode" == "run" ]]; then
    pacman -Syu --noconfirm fftw mbedtls yaml-cpp lksctp-tools gtest
fi
if [[ "$mode" == "all" || "$mode" == "extra" ]]; then
    pacman -Syu --noconfirm zeromq libuhd boost dpdk libelf libdwarf elfutils
fi
