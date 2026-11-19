#!/bin/sh
# HTTP handler, run by `netcat -l -p 8080 -e` on the router (router's own tools only).
#   GET /                          control page
#   GET /api?a=set&state=on|off|toggle&dimming=&temp=&r=&g=&b=&c=&w=&sceneId=&speed=
#   GET /api?a=status              GET /api?a=timer&min=N  (0 cancels)
D=/run/wiz; T=$D/timer; CR=$(printf '\r')
. $D/config.sh  # BULB_MAC, BULB_IP (not in git; see config.example.sh)

send() {  # GNU netcat never exits in UDP mode: wait up to 1s for the reply, then kill it
  B=$(awk -v m="$BULB_MAC" 'tolower($4)==m{print $1}' /proc/net/arp); B=${B:-$BULB_IP}  # find bulb by MAC
  f=$D/r.$$.$RANDOM; : > $f
  printf '%s' "$1" | netcat -u -n $B 38899 > $f 2>/dev/null &
  p=$!; i=0
  while [ ! -s $f ] && [ $i -lt 10 ]; do usleep 100000; i=$((i + 1)); done
  kill $p 2>/dev/null; cat $f; rm -f $f
}
OFF='{"method":"setPilot","params":{"state":false}}'
GET='{"method":"getPilot","params":{}}'
field() { echo "$1" | sed -n "s/.*\"$2\":\([0-9]*\).*/\1/p"; }
pilot() { echo "{\"method\":\"setPilot\",\"params\":{$1}}"; }

# `sh monitor`: internet-down alarm. Both pings fail twice in a row -> blink red, stay red;
# back online -> restore what the bulb showed before. Never turns on a bulb that was off.
monitor() {
  fails=0; saved=""
  while :; do
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 || ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
      if [ -n "$saved" ]; then
        s=$(send "$GET")  # only restore if it's still our red (you may have changed it meanwhile)
        [ "$(field "$s" r)/$(field "$s" g)/$(field "$s" b)" = "255/0/0" ] && {
          send "$(pilot "$saved")" >/dev/null
          send "$(pilot "\"dimming\":${saved##*\"dimming\":}")" >/dev/null  # bulb drops dimming when leaving colour mode
        }
        saved=""
      fi
      fails=0
    else
      fails=$((fails + 1))
      if [ $fails -eq 2 ]; then
        s=$(send "$GET")
        case "$s" in *'"state":true'*)
          saved='"state":true'
          for k in sceneId speed temp r g b c w dimming; do
            v=$(field "$s" $k); [ -n "$v" ] && ! { [ $k = sceneId ] && [ $v = 0 ]; } && saved="$saved,\"$k\":$v"
          done
          for i in 1 2 3; do
            send "$(pilot '"r":255,"g":0,"b":0,"dimming":100')" >/dev/null; usleep 400000
            send "$(pilot '"r":255,"g":0,"b":0,"dimming":10')" >/dev/null; usleep 400000
          done
          send "$(pilot '"r":255,"g":0,"b":0,"dimming":100')" >/dev/null ;;
        esac
      fi
    fi
    sleep 20
  done
}
[ "$1" = monitor ] && { monitor; exit 0; }

# `sh fibrelog`: optical readings every 5 min -> $D/fibrelog (ring buffer, last 288 = 24h).
# Lets the Fibre scope plot laser bias (aging) and Rx power (dips) over time.
fibrelog() {
  L=$D/fibrelog
  while :; do
    rx=$(diag pon get transceiver rx-power </dev/null 2>/dev/null | awk '/Power:/{print $(NF-1);exit}')
    tx=$(diag pon get transceiver tx-power </dev/null 2>/dev/null | awk '/Power:/{print $(NF-1);exit}')
    tp=$(diag pon get transceiver temperature </dev/null 2>/dev/null | awk '/Temperature:/{print $(NF-1);exit}')
    bi=$(diag pon get transceiver bias-current </dev/null 2>/dev/null | awk '/Current:/{print $(NF-1);exit}')
    [ -n "$rx" ] && echo "$(date +%s) $rx $tx $tp $bi" >> $L
    tail -288 $L > $L.t 2>/dev/null && mv $L.t $L
    sleep 300
  done
}
[ "$1" = fibrelog ] && { fibrelog; exit 0; }

# each listener takes one request at a time (up.sh runs several); read -t stops an idle connection hogging one
read -t 1 -r method path ver || exit 0
while read -t 1 -r l; do case "$l" in "" | "$CR") break ;; esac; done
q=${path#*\?}; [ "$q" = "$path" ] && q=""
arg() { echo "&$q" | sed -n "s/.*&$1=\([a-z0-9]*\).*/\1/p"; }

# Content-Length lets the client finish and hang up first; netcat closes with a TCP reset,
# which would otherwise wipe the unread response. usleep gives it time to do so.
reply() { printf 'HTTP/1.0 %s\r\nContent-Type: %s\r\nContent-Length: %s\r\nConnection: close\r\n\r\n' "$1" "$2" "$3"; }
# pages: / -> home, /<name> -> pages/<name>.html, /style.css
route=${path%%\?*}
case "$route" in
/) page=home ;;
/api) page="" ;;
/style.css) printf 'HTTP/1.0 200 OK\r\nContent-Type: text/css\r\nContent-Length: %s\r\nCache-Control: max-age=3600\r\nConnection: close\r\n\r\n' $(wc -c < $D/pages/style.css)
  cat $D/pages/style.css; usleep 150000; exit 0 ;;
*) page=${route#/}; case "$page" in '' | *[!a-z0-9]*) page=missing ;; esac ;;
esac
if [ -n "$page" ]; then
  f=$D/pages/$page.html
  if [ -f "$f" ]; then reply "200 OK" text/html $(wc -c < $f); cat $f
  else reply "404 Not Found" text/plain 0; fi
  usleep 150000; exit 0
fi

# data builders, shared by single endpoints and the combined home call
netjson() {  # one ping
  ms=$(ping -c 1 -W 2 8.8.8.8 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p')
  if [ -n "$ms" ]; then echo "{\"up\":true,\"ms\":$ms}"; else echo '{"up":false}'; fi
}
fibrejson() {  # optical module readings via the router's own RTK diag tool (read-only gets)
  fj=""
  for k in rx-power tx-power temperature voltage bias-current; do
    v=$(diag pon get transceiver $k </dev/null 2>/dev/null | awk '/Power:|Temperature:|Voltage:|Current:/ { print $(NF-1); exit }')
    fj="$fj,\"$k\":${v:-null}"
  done
  # EPON identity + MPCP clock: our LLID on the shared fibre, and the 16ns-tick counter the OLT keeps us synced to
  llid=$(diag epon get llid-table </dev/null 2>/dev/null | awk '/valid:1/{print $3; exit}')
  mp=$(diag epon get local-time </dev/null 2>/dev/null | sed -n 's/.*time:0x\([0-9a-fA-F]*\).*/\1/p')
  [ -n "$mp" ] && mp=$(( 0x$mp )) || mp=null
  echo "{${fj#,},\"llid\":${llid:-null},\"mpcp\":${mp},\"mpcp_hz\":62500000}"
}
# Wi-Fi driver stats per station + ARP (mac->ip) + router hosts file (ip->name) as a JSON array.
# wired = in ARP, not on Wi-Fi, and seen on the bridge in the last 60s (drops ghosts of devices that left)
devarray() {
  F=$D/fdb.$$; brctl showmacs br0 > $F 2>/dev/null  # per-request file: listeners run in parallel
  echo "[$(awk -v fdb="$F" '
    function flush() {
      if (mac == "") return
      seen[mac] = 1; i = ip[mac]
      printf "%s{\"mac\":\"%s\",\"ip\":\"%s\",\"name\":\"%s\",\"band\":\"%s\",\"rssi\":%d,\"down\":%d,\"up\":%d,\"down_total\":%.0f,\"up_total\":%.0f,\"vendor\":\"%s\",\"since\":\"%s\",\"rate\":\"%s\"}", sep, mac, i, name[i], band, rssi, txa, rxa, txb, rxb, vend, lt, rate
      sep = ","; mac = ""
    }
    FNR == 1 { flush() }
    FILENAME == "/var/tmp/hosts" { if ($2 != "") { n = $2; sub(/\.bbrouter$/, "", n); gsub(/["\\]/, "", n); name[$1] = n }; next }
    FILENAME == "/proc/net/arp" { if ($3 == "0x2") { m = $4; gsub(":", "", m); ip[m] = $1 }; next }
    FILENAME == fdb { if ($3 == "no" && $4 + 0 < 60) { m = $2; gsub(":", "", m); fresh[m] = 1 }; next }
    $1 == "hwaddr:" { flush(); mac = $2; band = (FILENAME ~ /wlan1/) ? "2.4 GHz" : "5 GHz"; vend = lt = rate = ""; txb = rxb = txa = rxa = rssi = 0 }
    $1 == "tx_bytes:" { txb = $2 }   $1 == "rx_bytes:" { rxb = $2 }
    $1 == "tx_avarage:" { txa = $2 } $1 == "rx_avarage:" { rxa = $2 }
    $1 == "rssi:" { rssi = $2 }
    /Chip Vendor:/ { vend = $3 }
    /current_tx_rate:/ { rate = $NF }
    /link_time:/ { lt = $0; sub(/.*link_time: */, "", lt); sub(/ *$/, "", lt) }
    END {
      flush()
      for (m in ip) if (!(m in seen) && (m in fresh)) { i = ip[m]; printf "%s{\"mac\":\"%s\",\"ip\":\"%s\",\"name\":\"%s\",\"band\":\"wired\"}", sep, m, i, name[i]; sep = "," }
    }' /var/tmp/hosts /proc/net/arp $F /proc/wlan*/sta_info 2>/dev/null)]"
  rm -f $F
}

case "$(arg a)" in
set)
  p=""
  for k in dimming temp r g b c w sceneId speed; do  # whitelist: reset/reboot unreachable
    v=$(arg $k); case "$v" in '' | *[!0-9]*) ;; *) p="$p,\"$k\":$v" ;; esac
  done
  case "$(arg state)" in
    on) p="$p,\"state\":true" ;;
    off) p="$p,\"state\":false" ;;
    toggle) case "$(send '{"method":"getPilot","params":{}}')" in
              *'"state":true'*) p="$p,\"state\":false" ;; *) p="$p,\"state\":true" ;; esac ;;
  esac
  r=$(send "{\"method\":\"setPilot\",\"params\":{${p#,}}}") ;;
status)
  r=$(send '{"method":"getPilot","params":{}}') ;;
net) r=$(netjson) ;;
fibre) r=$(fibrejson) ;;
fibrelog)  # laser-health history: "epoch rx tx temp bias" lines -> JSON array
  r="{\"samples\":[$(awk '{printf "%s[%s,%s,%s,%s,%s]", sep, $1, $2, $3, $4, $5; sep=","}' $D/fibrelog 2>/dev/null)]}" ;;
devices) r="{\"devices\":$(devarray)}" ;;
home)  # everything the home page shows, in one request
  b=$(send "$GET")
  r="{\"bulb\":${b:-null},\"net\":$(netjson),\"devices\":$(devarray),\"fibre\":$(fibrejson)}" ;;
timer)
  m=$(arg min); case "$m" in '' | *[!0-9]*) m=0 ;; esac
  rm -f $T  # cancels any running timer loop
  if [ "$m" -gt 0 ]; then
    end=$(( $(date +%s) + m * 60 )); echo $end > $T
    ( while [ "$(cat $T 2>/dev/null)" = "$end" ]; do
        [ "$(date +%s)" -ge $end ] && { send "$OFF" >/dev/null; rm -f $T; break; }
        sleep 10
      done ) </dev/null >/dev/null 2>&1 &
  fi
  r='{"ok":true}' ;;
*) r='{"error":"unknown action"}' ;;
esac
[ -n "$r" ] || r='{"error":"bulb not responding"}'
left=0; [ -f $T ] && left=$(( ($(cat $T) - $(date +%s) + 59) / 60 ))
body="${r%\}},\"timer_min_left\":$left}"
reply "200 OK" application/json $(( ${#body} + 1 )); echo "$body"; usleep 150000
