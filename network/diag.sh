#!/bin/bash
# Home-internet diagnosis. RUN THIS WHILE CONNECTED TO THE HOME WI-FI (the fibre router, 192.168.1.1).
# It never changes anything — read-only. Writes one report file; bring that back to Claude.
#   bash ~/wiz/network/diag.sh
set +e
OUT=~/wiz/network/diag-$(date +%Y%m%d-%H%M%S).txt
R=192.168.1.1
exec > >(tee "$OUT") 2>&1
echo "================ tazer / internet diagnosis ================"
echo "when: $(date)"
echo

sec() { echo; echo "----- $* -----"; }

sec "1. This Mac's network"
echo "Wi-Fi IP (en0): $(ipconfig getifaddr en0 2>/dev/null || echo none)"
echo "Default gateway: $(route -n get default 2>/dev/null | awk '/gateway/{print $2}')"
echo "Mac DNS servers: $(scutil --dns 2>/dev/null | awk '/nameserver\[/{print $3}' | sort -u | tr '\n' ' ')"
echo "SSID: $(ipconfig getsummary en0 2>/dev/null | awk -F' : ' '/ SSID/{print $2; exit}')"

sec "2. Can the Mac reach the router at $R"
ping -c2 -t2 $R | tail -3
ROUTER_UP=$?

sec "3. DNS vs raw IP (tells apart 'DNS broken' from 'no internet at all')"
echo "-- ping 8.8.8.8 by IP (no DNS needed):"; ping -c2 -t3 8.8.8.8 | tail -3
echo "-- ping 1.1.1.1 by IP:"; ping -c2 -t3 1.1.1.1 | tail -3
echo "-- resolve google.com via router DNS:"; dig +time=3 +tries=1 @$R google.com +short 2>&1 | head -3
echo "-- resolve google.com via public DNS 8.8.8.8:"; dig +time=3 +tries=1 @8.8.8.8 google.com +short 2>&1 | head -3

sec "4. Is tazer up (did our RAM setup survive, i.e. did the router reboot)"
curl -s -m4 -o /dev/null -w "tazer server .2:80 -> HTTP %{http_code}\n" -H "Host: tazer" http://192.168.1.2/ 2>&1
echo "(000 = tazer down = router rebooted = our stuff already wiped = NOT the cause)"

# ---- Router-side truth over SSH (read-only). Needs the home router; password is the default 'root'. ----
sec "5. Router-side diagnostics (SSH)"
AP=$(mktemp); printf '#!/bin/sh\necho root\n' > "$AP"; chmod 700 "$AP"
RSH() { SSH_ASKPASS="$AP" SSH_ASKPASS_REQUIRE=force DISPLAY=x \
  ssh -o ConnectTimeout=8 -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 \
      -o KexAlgorithms=+diffie-hellman-group1-sha1 -o HostKeyAlgorithms=+ssh-rsa -o Ciphers=+3des-cbc \
      -o StrictHostKeyChecking=accept-new root@$R "$1" </dev/null 2>&1; }

if RSH 'echo ok' | grep -q ok; then
  echo ">> SSH reached the router."
  echo; echo "[uptime — low = recently rebooted = our setup was already wiped]"; RSH 'cat /proc/uptime 2>/dev/null; echo'
  echo; echo "[WAN / PPPoE session — is the internet link itself up?]"
  RSH 'ifconfig ppp0 2>/dev/null | grep -E "inet addr|P-t-P" || echo "ppp0 DOWN / no PPPoE session"'
  RSH 'ip route 2>/dev/null | grep default || echo "no default route"'
  echo; echo "[FIBRE optical levels — the big one. Rx below -27 dBm or no reading = line/ISP problem]"
  for k in rx-power tx-power temperature voltage bias-current; do
    printf "  %-13s " "$k:"; RSH "diag pon get transceiver $k </dev/null 2>/dev/null | awk '/Power:|Temperature:|Voltage:|Current:/{print \$(NF-1);exit}'"; done
  echo; echo "[EPON registration — is the ONT registered with the ISP's OLT?]"
  RSH 'diag epon get llid-table </dev/null 2>/dev/null | grep valid:1 || echo "NO valid LLID = not registered on the fibre"'
  RSH 'cat /proc/fiber_mode 2>/dev/null | head -1'
  echo; echo "[Router -> gateway and -> internet (from the router itself)]"
  RSH 'gw=$(ifconfig ppp0 | sed -n "s/.*P-t-P:\([0-9.]*\).*/\1/p"); echo "gateway=$gw"; ping -c2 -W2 ${gw:-10.190.128.1} 2>&1 | tail -2'
  RSH 'ping -c2 -W2 8.8.8.8 2>&1 | tail -2'
  echo; echo "[Did OUR stuff touch anything? LAN-side only, listed to rule it out]"
  RSH 'echo "alias IP:"; ip addr show br0 | grep "192.168.1.2" || echo "  (gone)"'
  RSH 'echo "our nat rules:"; iptables -t nat -S PREROUTING | grep -E "192.168.1.2|5353|808[0-2]" || echo "  (none — our setup is not loaded)"'
  RSH 'echo "side dnsmasq:"; pidof dnsmasq >/dev/null && ps | grep "[d]nsmasq -C /run" || echo "  (our dnsmasq not running)"'
  echo; echo "[Recent kernel/PON log — look for LOS (loss of signal), dereg, link down]"
  RSH 'dmesg 2>/dev/null | grep -iE "pon|epon|los|dereg|link|laser|fiber|dying" | tail -n 15 || echo "(no dmesg)"'
else
  echo ">> SSH could NOT reach the router."
  echo "   If the Mac can't even ping $R (section 2 failed), you're not on the home network."
  echo "   If ping works but SSH fails, the router's SSH may be in its lockout — power-cycle the router."
fi
rm -f "$AP"

echo; echo "================ END. Report saved to: $OUT ================"
echo "Bring this file (or paste it) back to Claude."
