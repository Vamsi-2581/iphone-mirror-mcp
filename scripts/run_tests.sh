#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Offline checks must never inherit permission to inspect/control a phone.
unset MIRROR_MCP_LIVE MIRROR_APPROVAL_FILE
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift_cmd() {
    action="$1"
    shift
    swift "$action" --cache-path .build/cache --config-path .build/config \
        --security-path .build/security --manifest-cache local \
        --force-resolved-versions --disable-keychain --disable-netrc "$@"
}
swift_cmd build
swift_cmd run restricted-offline-checks
python3 scripts/check_restrictions.py
python3 scripts/check_stdio.py
case "${1:-}" in
    --full) swift_cmd test ;;
    '') printf '%s\n' 'Targeted offline checks passed. Full XCTest suite requires Xcode; run with --full to attempt it.' ;;
    *) printf '%s\n' 'Usage: scripts/run_tests.sh [--full]' >&2; exit 2 ;;
esac
