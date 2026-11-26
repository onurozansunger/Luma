#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Library/Developer/CommandLineTools ]]; then export DEVELOPER_DIR=/Library/Developer/CommandLineTools;fi
# Some Command Line Tools releases do not auto-discover the bundled Swift Testing plugin.
PLUGIN="${DEVELOPER_DIR:-$(xcode-select -p)}/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -f "$PLUGIN" ]]; then
 swift test --scratch-path "${LUMA_TEST_BUILD:-${TMPDIR:-/tmp}/luma-tests}" --disable-xctest -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN"
else
 swift test --scratch-path "${LUMA_TEST_BUILD:-${TMPDIR:-/tmp}/luma-tests}" --disable-xctest
fi
