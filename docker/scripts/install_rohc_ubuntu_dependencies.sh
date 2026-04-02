#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Install ROHC build dependencies for Debian/Ubuntu. Usage: install_rohc_ubuntu_dependencies.sh [<mode>]
# Mode: build | run | all (default)
#

set -e

mode="${1:-all}"

if [[ "$mode" == "all" || "$mode" == "build" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates build-essential xz-utils autotools-dev automake libtool libpcap-dev libcmocka-dev

fi
if [[ "$mode" == "all" || "$mode" == "run" ]]; then
    :
fi
