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

# web server (one request at a time) + internet-down alarm; restart if running
[ -f loop.pid ] && { kill $(cat loop.pid); killall netcat; } 2>/dev/null
sh -c "while :; do netcat -l -p 8080 -e /run/wiz/sh; done" </dev/null >/dev/null 2>&1 & echo $! > loop.pid
[ -f mon.pid ] && kill $(cat mon.pid) 2>/dev/null
./sh monitor </dev/null >/dev/null 2>&1 & echo $! > mon.pid

# names: $IP:80 -> :8080, and a side dnsmasq on :5353 answering $NAMES (forwards the rest to the
# real dnsmasq) with LAN DNS routed through it. Never touch the real one: the router regenerates
# /var/dnsmasq.conf whenever it restarts.
ip addr show br0 | grep -q "$IP/" || ip addr add $IP/32 dev br0
iptables -t nat -S PREROUTING | grep -q "$IP/32.*8080" ||
  iptables -t nat -I PREROUTING 1 -d $IP -p tcp --dport 80 -j REDIRECT --to-ports 8080
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
ok "web server"     'kill -0 $(cat loop.pid)'
ok "internet alarm" 'kill -0 $(cat mon.pid)'
ok "names DNS"      'kill -0 $(cat dns.pid)'
ok "IP $IP :80"     'iptables -t nat -S PREROUTING | grep -q 8080'
ok "bulb reachable" 'printf "GET /api?a=status HTTP/1.0\r\n\r\n" | ./sh | grep -q result'
