#!/usr/bin/env bash
# Usage: ./bench.sh ./c-woomer ./woomer [runs]
# Hyprland: time from launch until the app's window is mapped (shows in `hyprctl clients`).
# Works for both XWayland (c-woomer) and native Wayland (woomer) windows.
# ponytail: each poll costs a hyprctl call (~1-3 ms resolution), same for both binaries.
set -u
runs=${3:-20}

one() {  # prints ms until window mapped
  local s e pid n=0
  s=$(date +%s%N)
  setsid "$1" >/dev/null 2>&1 & pid=$!   # own process group: kill app + children (grim)
  until hyprctl clients -j | grep -q "\"pid\": $pid,"; do
    n=$((n+1)); [ $n -gt 10000 ] && { echo "no window for $1" >&2; break; }
  done
  e=$(date +%s%N)
  kill -TERM -- -"$pid" 2>/dev/null; sleep 0.3; kill -KILL -- -"$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  echo $(( (e-s)/1000000 ))
}

bench() {
  for i in $(seq "$runs"); do one "$1"; sleep 0.5; done | sort -n | awk -v n="$1" '{a[NR]=$1; s+=$1}
    END{printf "%-12s avg %4.0f ms  median %4d  min %4d  max %4d  (n=%d)\n", n, s/NR, a[int((NR+1)/2)], a[1], a[NR], NR}'
}

[ $# -ge 2 ] || { echo "usage: $0 binary_a binary_b [runs]"; exit 1; }
one "$1" >/dev/null; one "$2" >/dev/null   # warmup (cold cache)
bench "$1"
bench "$2"
