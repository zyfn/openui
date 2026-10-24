#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift test --package-path ../../../packages/swift-ui
./build-app.sh
