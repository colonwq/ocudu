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
    if [ $# -lt 1 ] || [ $# -gt 3 ]; then
        echo >&2 "Illegal number of parameters"
        echo >&2 "Run like this: \"./build_uhd.sh <uhd_version> [<arch> [<ncores>]]\" where arch is any gcc/clang compatible -march and ncores could be any number or empty for all"
        exit 1
    fi

    local uhd_version=$1
    local arch="${2:-native}"
    local ncores="${3:-$(nproc)}"

    set -x
    cd /tmp
    local tarball="/tmp/uhd-v${uhd_version}.tar.gz"
    curl -fsSL -o "${tarball}" "https://github.com/EttusResearch/uhd/archive/refs/tags/v${uhd_version}.tar.gz"
    curl_ret=$?
    if [ ${curl_ret} -ne 0 ]; then
        echo >&2 "UHD download failed (curl exit code ${curl_ret})"
        exit 1
    fi
    if [ ! -f "${tarball}" ] || [ "$(wc -c < "${tarball}")" -le 2048 ]; then
        echo >&2 "UHD download too small or missing (check tag v${uhd_version} exists at https://github.com/EttusResearch/uhd/releases)"
        [ -s "${tarball}" ] && head -c 500 "${tarball}" >&2 || true
        exit 1
    fi
    tar xzf "${tarball}"
    rm -f "${tarball}"
    set +x

    # Add missing #include <cstdint> to headers that use uint32_t etc. (GCC 15+ on Fedora 43)
    UHD_TOP=$(ls -d /tmp/uhd-*"${uhd_version}"* 2>/dev/null | head -1)
    if [ -n "$UHD_TOP" ] && [ -d "${UHD_TOP}/host" ]; then
        find "${UHD_TOP}/host" \( -name '*.hpp' -o -name '*.h' \) -print0 | while IFS= read -r -d '' f; do
            if grep -qE 'uint32_t|uint16_t|uint8_t|int32_t' "$f" && ! grep -q '<cstdint>' "$f"; then
                sed -i '1i #include <cstdint>' "$f"
            fi
        done
    fi

    cd uhd*"${uhd_version}"/host && mkdir -p build && cd build
    cmake \
        -DCMAKE_INSTALL_PREFIX=/opt/uhd/"${uhd_version}" \
        -DENABLE_LIBUHD=On \
        -DENABLE_PYTHON_API=Off \
        -DENABLE_EXAMPLES=Off \
        -DENABLE_TESTS=Off \
        -DCMAKE_CXX_FLAGS="-march=${arch}" ..
    cmake --build . -- -j"${ncores}"
    cmake --install .

    rm -Rf /tmp/uhd*"${uhd_version}"

}

main "$@"
