#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
RUNTIME="$ROOT/runtime-install-x86_64"

mkdir -p "$RUNTIME"
cp "$ROOT/runtime-install/package.json" "$RUNTIME/package.json"
cp "$ROOT/runtime-install/package-lock.json" "$RUNTIME/package-lock.json"

if [[ ! -d "$RUNTIME/node_modules/@img/sharp-darwin-x64" ]] || \
   [[ ! -d "$RUNTIME/node_modules/@koromix/koffi-darwin-x64" ]]; then
  # Install the lockfile's x86_64 prebuilt optional packages. Running lifecycle
  # scripts under the host arm64 Node would make koffi rebuild for arm64.
  npm ci --prefix "$RUNTIME" --os=darwin --cpu=x64 --ignore-scripts --no-audit --no-fund
fi

DSH_BUILD_ARCH=x86_64 \
DSH_DIST_DIR=dist-x86_64 \
DSH_RUNTIME_PATH="$RUNTIME" \
  "$ROOT/build.sh"
