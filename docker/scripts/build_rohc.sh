#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#

set -e # stop executing after error

# Ensure standard paths so aclocal/autoconf/automake are found (e.g. in minimal containers)
export PATH="/usr/bin:/bin${PATH:+:$PATH}"
# Force autotools to use system binaries (autogen.sh may not inherit PATH in some environments)
export ACLOCAL="${ACLOCAL:-/usr/bin/aclocal}"
export AUTOCONF="${AUTOCONF:-/usr/bin/autoconf}"
export AUTOMAKE="${AUTOMAKE:-/usr/bin/automake}"
export AUTOHEADER="${AUTOHEADER:-/usr/bin/autoheader}"
export LIBTOOLIZE="${LIBTOOLIZE:-/usr/bin/libtoolize}"

main() {
    # Check number of args
    if [ $# -lt 0 ] || [ $# -gt 2 ]; then
        echo >&2 "Illegal number of parameters"
        echo >&2 "Run like this: \"./build_rohc.sh [<arch> [<ncores>]]\" where arch is any gcc/clang compatible -march and ncores could be any number or empty for all"
        exit 1
    fi

    local arch="${1:-native}"
    local ncores="${2:-$(nproc)}"
    local rohc_name="rohc"
    local rohc_version="2.3.1"
    local rohc_archive="${rohc_name}-${rohc_version}.tar.xz"
    local rohc_archive_sha256sum="e5c3808518239a6a4673c0c595356d5054b208f32e39015a487a0490d03f9bec"
    local SHA256SUM_CHECKLINE="${rohc_archive_sha256sum}  ${rohc_archive}"

    cd /tmp
    curl "https://rohc-lib.org/download/rohc-2.3.x/${rohc_version}/${rohc_archive}" -o "${rohc_archive}"
    if ! echo "$SHA256SUM_CHECKLINE" | sha256sum -c -; then
        echo "Checksum verification failed for ${rohc_archive}"
        exit 1
    fi
    tar -xf "${rohc_archive}"

    pushd "${rohc_name}-${rohc_version}"
    # Run autogen with explicit PATH so aclocal is found (required in some container environments)
    env PATH="/usr/bin:/bin${PATH:+:$PATH}" ./autogen.sh
    ./configure --prefix=/opt/rohc
    make all -j"${ncores}"
    make install
    ldconfig
    popd
    
    rm -Rf /tmp/"${rohc_name}-${rohc_version}"*

}

main "$@"
