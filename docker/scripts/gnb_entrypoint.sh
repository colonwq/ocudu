#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# Entrypoint for the gNB container. When ENABLE_GDB is set to a non-empty
# value (e.g. "1" or "true"), runs gnb under GDB in batch mode to print
# a backtrace on crash (SIGSEGV/SIGILL etc.). Otherwise runs gnb directly.
# Pass gnb arguments as container args (e.g. -c /gnb_config.yml -c /gnb_compose_config.yml).

set -e

GNB_BIN="/usr/local/bin/gnb"

if [ -n "${ENABLE_GDB}" ]; then
    exec gdb -batch \
        -ex "run" \
        -ex "bt full" \
        -ex "info registers" \
        -ex "quit" \
        --args "${GNB_BIN}" "$@"
else
    exec "${GNB_BIN}" "$@"
fi
