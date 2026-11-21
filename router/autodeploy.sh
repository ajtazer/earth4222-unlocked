#!/bin/bash
# Auto-recovery: redeploy tazer only if it's down. Run by the LaunchAgent (see install note at bottom).
# Does nothing when tazer is already up, or when you're not on the home network.
cd "$(dirname "$0")"
LOG=/tmp/wiz-autodeploy.log

# router not reachable (away from home) -> try again next time
ping -c1 -t2 192.168.1.1 >/dev/null 2>&1 || exit 0
# already up? the one-at-a-time server can refuse a lone request, so only treat it as down
# after several misses — a needless redeploy means a needless SSH login, which risks the lockout
for i in 1 2 3 4 5; do
  curl -s -m4 -o /dev/null -H "Host: tazer" http://192.168.1.2/ && exit 0
  sleep 2
done

echo "$(date '+%F %T') tazer down, redeploying" >> "$LOG"
AP=$(mktemp); printf '#!/bin/sh\necho root\n' > "$AP"; chmod 700 "$AP"   # router default password
SSH_ASKPASS="$AP" SSH_ASKPASS_REQUIRE=force DISPLAY=x ./deploy.sh >> "$LOG" 2>&1
rm -f "$AP"
