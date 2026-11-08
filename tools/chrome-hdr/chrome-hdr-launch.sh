#!/bin/bash
# Launch Google Chrome with HDR enabled on Intel built-in displays.
#
# Chromium deliberately disables HDR on x86 machines when the built-in display
# reports maximumPotentialExtendedDynamicRangeColorComponentValue <= 2.0
# (see crbug.com/1402882), so YouTube never receives HDR formats. Forcing the
# HDR color profile at startup bypasses that policy; verified on this machine:
# YouTube offered/played format 337 (2160p60 HDR, VP9.2) and the display's live
# EDR reached 2.0 while playing.
#
# Install: copy to /Applications as "Chrome HDR.app/Contents/MacOS/ChromeHDR"
# (see README) or run this script directly. It quits Chrome first because the
# switch is only read at process start and the default profile is single-instance.
set -e
osascript -e 'tell application "Google Chrome" to quit' >/dev/null 2>&1 || true
for i in $(seq 1 20); do
  if ! pgrep -x "Google Chrome" >/dev/null 2>&1; then break; fi
  sleep 0.5
done
if pgrep -x "Google Chrome" >/dev/null 2>&1; then
  osascript -e 'display dialog "请先完全退出 Chrome，再运行本启动器。" buttons {"好"} default button 1' >/dev/null 2>&1 || true
  exit 1
fi
open -na "Google Chrome" --args --force-color-profile=hdr10
