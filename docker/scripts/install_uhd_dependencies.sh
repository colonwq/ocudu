#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#

#
# This script will install UHD dependencies
#
# Run like this: ./install_uhd_dependencies.sh [<mode>]
# E.g.: ./install_uhd_dependencies
# E.g.: ./install_uhd_dependencies build
# E.g.: ./install_uhd_dependencies run
# E.g.: ./install_uhd_dependencies all
#

set -e

# Check number of args
if [ $# != 0 ] && [ $# != 1 ]; then
    echo >&2 "Illegal number of parameters"
    echo >&2 "Run like this: \"./install_uhd_dependencies.sh [<mode>]\" where mode could be: build, run and all"
    echo >&2 "If mode is not specified, all dependencies will be installed"
    exit 1
fi

mode="${1:-all}"
# shellcheck source=/dev/null
. /etc/os-release

echo "== Installing UHD dependencies, mode $mode =="

script_dir="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"

if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
    bash "$script_dir/install_uhd_ubuntu_dependencies.sh" "$mode"
elif [[ "$ID" == "arch" ]]; then
    bash "$script_dir/install_uhd_arch_dependencies.sh" "$mode"
elif [[ "$ID" == "rhel" ]]; then
    bash "$script_dir/install_uhd_rhel_dependencies.sh" "$mode"
elif [[ "$ID" == "fedora" || "$ID" == "centos" ]]; then
    bash "$script_dir/install_uhd_fedora_dependencies.sh" "$mode"
else
    echo "OS $ID not supported"
    exit 1
fi
