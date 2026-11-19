#!/bin/bash
# Rebuild everything on the router after a reboot (it all lives in RAM). Safe to re-run any time.
# Copies wiz.sh (as /run/wiz/sh), up.sh, config.sh and pages/ to the router, then runs up.sh there.
# Asks for the router password once, then reuses that one connection for 4 hours: the router's inetd
# stops starting SSH after a burst of new logins (only a router restart clears it), so never loop retries.
# One short remote command: dropbear 0.48 drops long ones.
set -euo pipefail
cd "$(dirname "$0")"
COPYFILE_DISABLE=1 tar -cf - wiz.sh up.sh config.sh pages |
  ssh -o KexAlgorithms=+diffie-hellman-group1-sha1 -o HostKeyAlgorithms=+ssh-rsa -o Ciphers=+3des-cbc \
      -o PubkeyAuthentication=no -o ControlMaster=auto -o ControlPath=~/.ssh/cm-router -o ControlPersist=4h root@192.168.1.1 \
      'mkdir -p /run/wiz && cd /run/wiz && rm -rf pages && tar -xf - && mv wiz.sh sh && chmod +x sh && sh up.sh'
# handler is named `sh`: GNU netcat -e runs it via busybox with argv0=basename; busybox only answers to applet names
echo "Open http://tazer   (Mac says it can't find it? run: sudo killall -HUP mDNSResponder)"
