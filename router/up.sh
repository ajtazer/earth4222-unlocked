#!/bin/sh
# Runs ON the router: deploy.sh copies it into /run/wiz and runs it. Idempotent; prints a checklist.
cd /run/wiz
# inline style.css into every page: the server takes one request at a time, so a separate
# stylesheet request from a phone (fired alongside the page) often gets refused -> unstyled page
for f in pages/*.html; do
  awk -v css=pages/style.css '/<link rel="stylesheet" href="\/style.css">/ { print "<style>"; while ((getline l < css) > 0) print l; print "</style>"; next } { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done

NAMES="tazer"     # http://<name> -> pages server. Add a name here, re-deploy.
IP=192.168.1.2    # spare LAN IP outside the DHCP pool (.33-.254)

# web server: GNU netcat takes one connection per run, so run several listeners and let
# iptables deal new connections across them (below); plus the internet-down alarm. Restart if running.
PORTS="8080 8081 8082"
[ -f loop.pid ] && { kill $(cat loop.pid); killall netcat; } 2>/dev/null
: > loop.pid
for p in $PORTS; do
  sh -c "while :; do netcat -l -p $p -e /run/wiz/sh; done" </dev/null >/dev/null 2>&1 & echo $! >> loop.pid
done
[ -f mon.pid ] && kill $(cat mon.pid) 2>/dev/null
./sh monitor </dev/null >/dev/null 2>&1 & echo $! > mon.pid

# names: $IP:80 -> :8080, and a side dnsmasq on :5353 answering $NAMES (forwards the rest to the
# real dnsmasq) with LAN DNS routed through it. Never touch the real one: the router regenerates
# /var/dnsmasq.conf whenever it restarts.
ip addr show br0 | grep -q "$IP/" || ip addr add $IP/32 dev br0
# spread simultaneous connections over the listeners. This kernel lacks statistic, multiport, u32 and
# recent, and Macs pick sequential source ports, so use the limit match as a token bucket: 8081 and 8082
# each take at most one new connection per 250ms (a listener needs ~190ms to re-arm), the rest go to 8080.
# A page plus its parallel requests lands on three different listeners. Drop our old :80 rules first.
iptables -t nat -S PREROUTING | grep -- "-d $IP/32 .*--dport 80 " | sed 's/^-A /-D /' | while read -r rule; do iptables -t nat $rule; done
iptables -t nat -I PREROUTING 1 -d $IP -p tcp --dport 80 -j REDIRECT --to-ports 8080
iptables -t nat -I PREROUTING 1 -d $IP -p tcp --dport 80 -m limit --limit 4/second --limit-burst 1 -j REDIRECT --to-ports 8082
iptables -t nat -I PREROUTING 1 -d $IP -p tcp --dport 80 -m limit --limit 4/second --limit-burst 1 -j REDIRECT --to-ports 8081
printf 'user=\ngroup=\nno-resolv\ndomain-needed\nserver=127.0.0.1\n' > dns.conf  # domain-needed: plain names never leave the house
for n in $NAMES; do printf 'address=/%s/%s\naddress=/%s.bbrouter/%s\n' $n $IP $n $IP >> dns.conf; done
[ -f dns.pid ] && kill $(cat dns.pid) 2>/dev/null && sleep 1
dnsmasq -C /run/wiz/dns.conf -p 5353 -x /run/wiz/dns.pid </dev/null >/dev/null 2>&1; sleep 1
if kill -0 $(cat dns.pid 2>/dev/null) 2>/dev/null; then
  for p in udp tcp; do
    iptables -t nat -S PREROUTING | grep -q "$p.*dport 53 -j REDIRECT" ||
      iptables -t nat -I PREROUTING 1 -i br0 -d 192.168.1.1 -p $p --dport 53 -j REDIRECT --to-ports 5353
  done
else  # never leave LAN DNS pointing at a dead server
  for p in udp tcp; do iptables -t nat -D PREROUTING -i br0 -d 192.168.1.1 -p $p --dport 53 -j REDIRECT --to-ports 5353 2>/dev/null; done
  echo "WARNING: side dnsmasq failed; names off, normal DNS untouched"
fi

ok() { if eval "$2" >/dev/null 2>&1; then echo "  ok    $1"; else echo "  FAIL  $1"; fi; }
ok "web servers x3" 'for p in $(cat loop.pid); do kill -0 $p || exit 1; done'
ok "internet alarm" 'kill -0 $(cat mon.pid)'
ok "names DNS"      'kill -0 $(cat dns.pid)'
ok "IP $IP :80 x3"  '[ "$(iptables -t nat -S PREROUTING | grep -c -- "-d $IP/32 .*--dport 80 ")" = 3 ]'
ok "bulb reachable" 'printf "GET /api?a=status HTTP/1.0\r\n\r\n" | ./sh | grep -q result'
