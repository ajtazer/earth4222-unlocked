#!/bin/bash
# Builds router/dnsmasq: a static dnsmasq for the router (MIPS32r2 big-endian, soft-float, musl), shipped by deploy.sh.
# Why: the vendor's dnsmasq 2.45 (2008) loses 10-30% of "no such name / no such record" answers (measured 2026-11-25);
# up.sh runs this one for LAN DNS instead. Needs zig (brew install zig). Compiles the sources directly, no Makefile.
set -euo pipefail
V=2.90 SHA=8f6666b542403b5ee7ccce66ea73a4a51cf19dd49392aaccd37231a2c51b303b
cd "$(dirname "$0")"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
curl -fsSL -o "$T/src.tgz" https://thekelleys.org.uk/dnsmasq/dnsmasq-$V.tar.gz
echo "$SHA  $T/src.tgz" | shasum -a 256 -c --quiet
tar -xzf "$T/src.tgz" -C "$T"
zig cc -target mips-linux-musleabi -mcpu=mips32r2 -Os -static -s -ffunction-sections -Wl,--gc-sections \
  -DVERSION="\"$V\"" -DNO_DHCP -DNO_DHCP6 -DNO_TFTP -DNO_SCRIPT -DNO_AUTH -DNO_IPSET -DNO_LOOP -DNO_DUMPFILE -DNO_INOTIFY \
  -o dnsmasq "$T"/dnsmasq-$V/src/*.c
file dnsmasq
