portal | portaloff)  # arm a device (mac=aabbccddeeff) / disarm it (mac, or whoever is asking)
  m=$(arg mac)
  if [ -z "$m" ]; then  # one request at a time, so the only ESTABLISHED conn on :8080 is the asker
    h=$(awk '$4 == "01" && $2 ~ /:1F90$/ { split($3, a, ":"); print a[1]; exit }' /proc/net/tcp)
    pip=$(printf '%d.%d.%d.%d' $(echo "$h" | sed 's/\(..\)\(..\)\(..\)\(..\)/0x\1 0x\2 0x\3 0x\4/'))
    m=$(awk -v i="$pip" '$1 == i { gsub(":", "", $4); print $4 }' /proc/net/arp)
  fi
  case "$m" in [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;; *) m="" ;; esac
  if [ -z "$m" ]; then r='{"error":"unknown device"}'
  else
    M=$(echo $m | sed 's/../&:/g; s/:$//')
    rule="PREROUTING -m mac --mac-source $M -p tcp --dport 80 -j REDIRECT --to-ports 8080"
    while iptables -t nat -D $rule 2>/dev/null; do :; done
    [ "$(arg a)" = portal ] && iptables -t nat -I PREROUTING 1 ${rule#PREROUTING }
    r="{\"ok\":true,\"mac\":\"$m\"}"
  fi ;;
