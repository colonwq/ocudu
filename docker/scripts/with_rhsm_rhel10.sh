#!/bin/bash
#
# Copyright 2021-2026 Software Radio Systems Limited
#
# By using this file, you agree to the terms and conditions set
# forth in the LICENSE file which can be found at the top level of
# the distribution.
#
# RHEL 10 / UBI 10 only: optionally register with subscription-manager using
# BuildKit/Podman secrets, enable CodeReady Builder, and run the given command.
# Safe to invoke from multiple install scripts in one RUN: already-registered systems
# only re-enable CRB and run the command. Does not unregister on exit.
#
# Usage: RHSM_SECRET_FILE=/run/secrets/rhsm_build_creds bash with_rhsm_rhel10.sh COMMAND [ARGS...]
#
# Secret file (not in git; pass via --secret id=rhsm_build_creds,src=FILE) is a shell snippet
# setting either RHSM_ORG + RHSM_ACTIVATION_KEY or RHSM_USERNAME + RHSM_PASSWORD.
#

set -euo pipefail

secret_file="${RHSM_SECRET_FILE:-/run/secrets/rhsm_build_creds}"

# shellcheck source=/dev/null
. /etc/os-release

if [[ "$ID" != "rhel" ]]; then
    echo "with_rhsm_rhel10.sh: requires RHEL (os-release ID=rhel), got ID=${ID:-}" >&2
    exit 1
fi

if [[ "${VERSION_ID:-0}" != 10* ]]; then
    echo "with_rhsm_rhel10.sh: requires RHEL major version 10, got VERSION_ID=${VERSION_ID:-}" >&2
    exit 1
fi

enable_crb_repo() {
    local arch crb_repo
    arch=$(uname -m)
    crb_repo="codeready-builder-for-rhel-10-${arch}-rpms"
    subscription-manager repos --enable="$crb_repo" 2>/dev/null || true
}

# Earlier install step in the same image already registered
if command -v subscription-manager >/dev/null 2>&1 && subscription-manager identity >/dev/null 2>&1; then
    export RHSM_USING_SUBSCRIPTION=1
    enable_crb_repo
    exec "$@"
fi

if [[ ! -f "$secret_file" ]] || [[ ! -s "$secret_file" ]]; then
    exec "$@"
fi

set +u
# shellcheck disable=SC1090
source "$secret_file"
set -u

if [[ -z "${RHSM_ORG:-}" || -z "${RHSM_ACTIVATION_KEY:-}" ]] \
    && [[ -z "${RHSM_USERNAME:-}" || -z "${RHSM_PASSWORD:-}" ]]; then
    echo "with_rhsm_rhel10.sh: secret file must set RHSM_ORG+RHSM_ACTIVATION_KEY or RHSM_USERNAME+RHSM_PASSWORD" >&2
    exit 1
fi

export RHSM_USING_SUBSCRIPTION=1

dnf -y install subscription-manager

if [[ -n "${RHSM_ORG:-}" && -n "${RHSM_ACTIVATION_KEY:-}" ]]; then
    subscription-manager register --org="$RHSM_ORG" --activationkey="$RHSM_ACTIVATION_KEY"
else
    subscription-manager register --username="$RHSM_USERNAME" --password="$RHSM_PASSWORD"
    subscription-manager attach --auto 2>/dev/null || true
fi

enable_crb_repo

exec "$@"
