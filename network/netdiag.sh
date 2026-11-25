#!/bin/bash
# Sequential Wi-Fi / home-network benchmark. Read-only. Pings never overlap the throughput test.
# Usage: bash ~/wiz/network/netdiag.sh   (optionally: bash ~/wiz/network/netdiag.sh after   -> tags the run)
set +e
TAG="${1:-baseline}"
OUT=~/wiz/network/netdiag-$TAG-$(date +%Y%m%d-%H%M%S).txt
exec > >(tee "$OUT") 2>&1
GW=$(route -n get default 2>/dev/null | awk '/gateway/{print $2}')
sec() { echo; echo "========== $* =========="; }

echo "### Network benchmark ($TAG) — $(date)"
echo "gateway: $GW"

sec "1a. Wi-Fi link (this Mac)"
system_profiler SPAirPortDataType 2>/dev/null | awk '/Current Network/{f=1} f&&/PHY Mode|Channel|Signal|Transmit Rate|MCS|Security|Network Type/{print} /Other Local Net/{f=0}' | head -20
echo "-- interface errors (en0):"; netstat -I en0 -b 2>/dev/null | awk 'NR==1||/Link/{print $1,$5,$6,$7,$8,$9,$10,$11}'

sec "1b. RF congestion per channel (from the router's own scan — better than a Mac scan)"
# filled in section 5 (router), kept here in the report order

sec "2a. Idle latency — gateway ($GW), 30 packets"
ping -c30 -q "$GW" 2>&1 | tail -3
sec "2b. Idle latency — 1.1.1.1, 30 packets"
ping -c30 -q 1.1.1.1 2>&1 | tail -3
if ifconfig en0 2>/dev/null | grep -q 'inet6.*global\|inet6 2'; then
  sec "2c. IPv6 latency — 2606:4700:4700::1111, 30 packets"; ping6 -c30 -q 2606:4700:4700::1111 2>&1 | tail -3
else echo; echo "(no global IPv6 — skipping IPv6 ping)"; fi
sec "2d. Traceroute (5 hops) to 1.1.1.1 — separates Wi-Fi/LAN from ISP"
traceroute -w2 -q1 -m5 1.1.1.1 2>&1
sec "2e. Local bandwidth hogs / VPN / recent roam events"
echo "-- VPN/tunnel interfaces up:"; ifconfig 2>/dev/null | grep -E '^(utun|ppp|ipsec|tap|tun)' | grep -i 'flags.*UP' || echo "  none active"
echo "-- top talkers right now (nettop 2s):"; nettop -P -L2 -J bytes_in,bytes_out -t wifi 2>/dev/null | tail -n +2 | sort -t, -k2 -nr 2>/dev/null | head -6 || echo "  (nettop unavailable)"
echo "-- recent Wi-Fi disconnect/roam events:"; log show --last 2h --style compact --predicate 'subsystem == "com.apple.wifi"' 2>/dev/null | grep -iE "disassoc|roam|deauth|link.*down|associat" | tail -8 || echo "  (none/unavailable)"

sec "3. DNS latency (uncached, random subdomain) — current vs 1.1.1.1 / 8.8.8.8 / router"
echo "current Mac DNS: $(scutil --dns 2>/dev/null | awk '/nameserver\[/{print $3}' | sort -u | tr '\n' ' ')"
for r in "$GW" 1.1.1.1 8.8.8.8; do
  q=$(dig +tries=1 +time=2 @"$r" "r$RANDOM.example.com" 2>/dev/null | awk -F': ' '/Query time/{print $2}')
  printf "  via %-10s %s\n" "$r" "${q:-timeout}"
done

sec "4. Throughput & bufferbloat (networkQuality -v) — runs ALONE, no pings during this"
networkQuality -v 2>&1 | grep -iE "Downlink|Uplink|Responsiveness|Idle Latency|Latency|RPM|ECN|capacity|flows" | head -20

sec "5. Router-side: Wi-Fi config + per-channel congestion (SSH, read-only)"
AP=$(mktemp); printf '#!/bin/sh\necho root\n' > "$AP"; chmod 700 "$AP"
RSH() { SSH_ASKPASS="$AP" SSH_ASKPASS_REQUIRE=force DISPLAY=x \
  ssh -o ConnectTimeout=8 -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 \
      -o KexAlgorithms=+diffie-hellman-group1-sha1 -o HostKeyAlgorithms=+ssh-rsa -o Ciphers=+3des-cbc \
      -o StrictHostKeyChecking=accept-new root@192.168.1.1 "$1" </dev/null 2>&1; }
if RSH 'echo ok' | grep -q ok; then
  echo "[radios: band / channel / width / mode]"
  RSH 'for w in wlan0 wlan1; do b=$(cat /proc/$w/mib_rf 2>/dev/null); echo "== $w"; cat /proc/$w/mib_operation 2>/dev/null | grep -iE "band|channel|bw|width|mode|2nd" | head -8; done' 2>&1 | head -30
  echo; echo "[config.xml wireless: channel / width / mode / band-steering / guest SSIDs]"
  RSH 'grep -oE "Name=\"(WLAN[01]?_?(CHANNEL|BAND|CHANNEL_BONDING|CHAN_WIDTH|BAND_WIDTH|WLAN_MODE|11N_BW|BANDSTEER|SMART_CONNECT|HTBW)|BAND_STEER[A-Z_]*|SMARTCONNECT[A-Z_]*)\" Value=\"[^\"]*\"" /var/config/config.xml 2>/dev/null | head -25'
  echo; echo "[guest / extra SSIDs enabled?]"
  RSH 'grep -oE "Name=\"WLAN[01]?_VAP[0-9]_ENABLE\" Value=\"[^\"]*\"" /var/config/config.xml 2>/dev/null | head'
  echo; echo "[per-channel load / noise (router ACS scan — lower score = cleaner)]"
  RSH 'for w in wlan0 wlan1; do echo "== $w ch_load:"; cat /proc/$w/ch_load 2>/dev/null | head -4; echo "   acs:"; cat /proc/$w/acs_score_info 2>/dev/null | head -20; done' 2>&1 | head -60
  echo; echo "[stations on each radio right now]"
  RSH 'for w in wlan0 wlan1; do echo "$w: $(grep -c hwaddr /proc/$w/sta_info 2>/dev/null) connected"; done'
else echo "  SSH to router failed — run this on the home Wi-Fi."; fi
rm -f "$AP"

echo; echo "### DONE ($TAG). Report: $OUT"
