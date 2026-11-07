#!/bin/bash
# AirportItlwm on Sequoia sometimes does not auto-join after boot until Wi-Fi is toggled.
# Wait for en0 to get an IPv4 address; if it doesn't within 60 s, power-cycle Wi-Fi (max 3 tries).
log(){ echo "$(date '+%F %T') $*"; }
for attempt in 1 2 3; do
  for i in $(seq 1 60); do
    if ipconfig getifaddr en0 >/dev/null 2>&1; then log "en0 has $(ipconfig getifaddr en0) (attempt $attempt, ${i}s)"; exit 0; fi
    sleep 1
  done
  log "no IP on en0 after 60 s, toggling Wi-Fi (attempt $attempt)"
  networksetup -setairportpower en0 off; sleep 3; networksetup -setairportpower en0 on
done
log "still no IP after 3 attempts"
