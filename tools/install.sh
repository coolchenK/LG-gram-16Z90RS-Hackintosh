#!/bin/bash
# Install the post-install helpers for the LG gram 16Z90RS (needs Xcode Command Line Tools).
#   sudo ./tools/install.sh
#
#   lggram-audiod  LaunchDaemon: initialises the 4 speaker amps, opens speaker pin 0x17,
#                  switches the amps on while audio plays and re-initialises after wake.
#                  Requires boot-arg alcverbs=1 (already in config.plist).
#   wifikick.sh    LaunchDaemon: power-cycles Wi-Fi once at boot if en0 has no IP after 60 s.
#   vi2ckick       touchpad helper: `vi2ckick diag`, and the manual fix
#                  `vi2ckick set 050300; vi2ckick set 030300`.
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }
cd "$(dirname "$0")"
T=$(mktemp -d)
xcrun swiftc -O -o "$T/lggram-audiod" audio/lggram-audiod.swift
xcrun clang -O -o "$T/vi2ckick" touchpad/vi2ckick.c -framework IOKit -framework CoreFoundation
mkdir -p /usr/local/bin
install -m 755 "$T/lggram-audiod" "$T/vi2ckick" audio/lg-gram-amp.sh wifikick/wifikick.sh /usr/local/bin/
install -m 644 -o root -g wheel audio/com.lggram.audiod.plist wifikick/com.lggram.wifikick.plist /Library/LaunchDaemons/
for s in com.lggram.audiod com.lggram.wifikick; do
  launchctl bootout system/$s 2>/dev/null || true
  launchctl bootstrap system /Library/LaunchDaemons/$s.plist
done
rm -rf "$T"
echo "installed: lggram-audiod, wifikick, vi2ckick"
