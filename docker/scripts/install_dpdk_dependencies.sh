#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#

set -e # stop executing after error

main() {

    # Check number of args
    if [ $# != 0 ] && [ $# != 1 ]; then
        echo >&2 "Illegal number of parameters"
        echo >&2 "Run like this: \"./install_dpdk_dependencies.sh [<mode>]\" where mode could be: build, run and all"
        echo >&2 "If mode is not specified, all dependencies will be installed"
        exit 1
    fi

    local mode="${1:-all}"

    # shellcheck source=/dev/null
    . /etc/os-release

    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        if [[ "$mode" == "all" || "$mode" == "build" ]]; then
            DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
                curl apt-transport-https ca-certificates xz-utils \
                python3-pip ninja-build g++ git build-essential pkg-config libnuma-dev libfdt-dev pciutils
            pip3 install meson pyelftools || pip3 install --break-system-packages meson pyelftools
        fi
        if [[ "$mode" == "all" || "$mode" == "run" ]]; then
            DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
                python3-pip libnuma-dev pciutils libfdt-dev libatomic1 iproute2
            pip3 install pyelftools || pip3 install --break-system-packages pyelftools
        fi
    elif [[ "$ID" == "fedora" || "$ID" == "rhel" ]]; then
        packages=()
        if [[ "$mode" == "all" || "$mode" == "build" ]]; then
            packages+=(gcc-c++ git libfdt-devel ninja-build numactl-devel pciutils pkg-config python3-pip)
        fi
        if [[ "$mode" == "all" || "$mode" == "run" ]]; then
            packages+=(iproute libatomic libfdt-devel numactl-devel pciutils python3-pip)
        fi
        if [[ ${#packages[@]} -gt 0 ]]; then
            dnf -y install "${packages[@]}"
        fi
        pip_modules=()
        if [[ "$mode" == "all" || "$mode" == "build" ]]; then
            pip_modules+=(meson pyelftools)
        fi
        if [[ "$mode" == "all" || "$mode" == "run" ]]; then
            pip_modules+=(pyelftools)
        fi
        if [[ ${#pip_modules[@]} -gt 0 ]]; then
            pip install "${pip_modules[@]}" || pip install --break-system-packages "${pip_modules[@]}"
        fi
    else
        echo "OS $ID not supported"
        exit 1
    fi

}

main "$@"
