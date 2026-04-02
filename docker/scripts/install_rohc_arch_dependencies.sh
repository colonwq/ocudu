#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Install ROHC build dependencies for Arch Linux. Usage: install_rohc_arch_dependencies.sh [<mode>]
# Mode: build | run | all (default)
#

set -e

mode="${1:-all}"

if [[ "$mode" == "all" || "$mode" == "build" ]]; then
    pacman -Syu --noconfirm base-devel autoconf automake libtool libpcap cmocka curl xz
fi
if [[ "$mode" == "all" || "$mode" == "run" ]]; then
    :
fi
