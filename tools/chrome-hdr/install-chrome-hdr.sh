#!/bin/bash
# Build /Applications/Chrome HDR.app from chrome-hdr-launch.sh.
# Requires admin rights only to write into /Applications.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
app="${1:-/Applications/Chrome HDR.app}"
if [ "$(id -u)" -ne 0 ] && [ ! -w "$(dirname "$app")" ]; then
  echo "需要写入 $(dirname "$app")，请用 sudo 运行。" >&2
  exit 1
fi
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
install -m 755 "$here/chrome-hdr-launch.sh" "$app/Contents/MacOS/ChromeHDR"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ChromeHDR</string>
<key>CFBundleIdentifier</key><string>local.chromehdr.launcher</string>
<key>CFBundleName</key><string>Chrome HDR</string>
<key>CFBundleDisplayName</key><string>Chrome HDR</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>11.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$app" >/dev/null 2>&1 || true
echo "已安装：$app"
echo "双击运行会先退出 Chrome，再以 HDR 色彩配置重新启动。"
