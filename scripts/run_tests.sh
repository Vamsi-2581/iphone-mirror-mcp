#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
unset MIRROR_MCP_LIVE
swift build
swift test
