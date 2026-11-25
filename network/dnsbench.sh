#!/bin/bash
# dnsbench.sh [server[:port] ...]: median / max / lost per resolver.
# new = random never-cached name (NXDOMAIN); empty = real name, missing record type (NODATA); popular = real sites.
n=${N:-20}; servers=${*:-"192.168.1.1 163.53.87.74 1.1.1.1 8.8.8.8"}
POP="google.com youtube.com instagram.com github.com wikipedia.org amazon.in netflix.com whatsapp.net apple.com reddit.com"
EMPTY="google youtube wikipedia apple netflix amazon.in reddit github instagram whatsapp microsoft bing yahoo linkedin twitter spotify flipkart hotstar zomato swiggy"
q() { dig +tries=1 +time=2 -p $p @$s "$@" | awk '/Query time/{print $4}'; }
stat() { sort -n | awk -v n="$1" '{a[NR]=$1} END{printf "%4s med %4s max %2d/%d lost", (NR?a[int((NR+1)/2)]:"-"), (NR?a[NR]:"-"), n-NR, n}'; }
for sp in $servers; do
  s=${sp%:*}; p=${sp#*:}; [ "$p" = "$sp" ] && p=53
  new=$(for i in $(seq $n); do q nx-$RANDOM$RANDOM.org; done | stat $n)
  emp=$(for d in $EMPTY; do h=www.$d; [[ $d == *.* ]] || h=$h.com; q MX $h; done | stat 20)
  pop=$(for d in $POP; do q $d; done | stat 10)
  printf '%-16s new %s | empty %s | popular %s\n' $sp "$new" "$emp" "$pop"
done
