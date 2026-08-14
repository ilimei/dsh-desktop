#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
APP="$ROOT/dist/DSH Desktop.app"
CONTENTS="$APP/Contents"

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "需要 Node.js 与 npm 才能构建 DSH Desktop。" >&2
  exit 1
fi

if [[ ! -f "$ROOT/runtime-install/node_modules/@deepseek-ai/dsh/lib/bin.js" ]]; then
  npm install --prefix "$ROOT/runtime-install" --no-audit --no-fund
fi

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
swiftc "$ROOT/DSHClient.swift" \
  -o "$CONTENTS/MacOS/DSHDesktop" \
  -framework AppKit -framework WebKit \
  -parse-as-library \
  -target arm64-apple-macos13.0
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/assets/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
ditto "$ROOT/runtime-install" "$CONTENTS/Resources/runtime"
ditto "$ROOT/plugin" "$CONTENTS/Resources/runtime/node_modules/dsh-desktop-web-client"
ditto "$ROOT/plugin" "$CONTENTS/Resources/dsh-desktop-web-client"
SIGN_IDENTITY="${DSH_CODESIGN_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
echo "$APP"
