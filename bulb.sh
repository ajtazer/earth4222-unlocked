B=192.168.1.34; PID=/tmp/wiz-timer.pid
send() { r=$(echo -n "{\"method\":\"setPilot\",\"params\":{$1}}" | nc -u -w 1 $B 38899)
  [[ $r == *success* ]] || { echo "Bulb didn't answer: $r"; exit 1; }; }
timer() { [[ -f $PID ]] && { pkill -P $(cat $PID); kill $(cat $PID); } 2>/dev/null
  nohup sh -c "sleep $(($1*60)); echo -n '{\"method\":\"setPilot\",\"params\":{\"state\":false}}' | nc -u -w 1 $B 38899; rm -f $PID" >/dev/null 2>&1 &
  echo $! > $PID; echo "Off in $1 min"; }
case "$(cat)" in
  '💡 On') send '"state":true' ;;
  '⚫ Off') send '"state":false' ;;
  '🔆 Warm white') send '"state":true,"temp":2700,"dimming":100' ;;
  '☀️ Neutral') send '"state":true,"temp":4200,"dimming":100' ;;
  '🌤 Daylight') send '"state":true,"temp":6500,"dimming":100' ;;
  '🌙 Night light') send '"state":true,"sceneId":14' ;;
  '🔅 Brightness 10%') send '"state":true,"dimming":10' ;;
  '🔅 Brightness 25%') send '"state":true,"dimming":25' ;;
  '🔆 Brightness 50%') send '"state":true,"dimming":50' ;;
  '🔆 Brightness 75%') send '"state":true,"dimming":75' ;;
  '🔆 Brightness 100%') send '"state":true,"dimming":100' ;;
  '🔴 Red') send '"state":true,"r":255,"g":0,"b":0' ;;
  '🟠 Orange') send '"state":true,"r":255,"g":90,"b":0' ;;
  '🩷 Pink') send '"state":true,"r":255,"g":20,"b":120' ;;
  '🟣 Purple') send '"state":true,"r":140,"g":0,"b":255' ;;
  '🔵 Blue') send '"state":true,"r":0,"g":40,"b":255' ;;
  '🟢 Green') send '"state":true,"r":0,"g":255,"b":40' ;;
  '🛋 Cozy') send '"state":true,"sceneId":6' ;;
  '🔥 Fireplace') send '"state":true,"sceneId":5' ;;
  '🌅 Sunset') send '"state":true,"sceneId":3' ;;
  '🌊 Ocean') send '"state":true,"sceneId":1' ;;
  '🎉 Party') send '"state":true,"sceneId":4' ;;
  '🧘 Relax') send '"state":true,"sceneId":16' ;;
  '🎯 Focus') send '"state":true,"sceneId":15' ;;
  '📺 TV time') send '"state":true,"sceneId":18' ;;
  '🕯 Candlelight') send '"state":true,"sceneId":29' ;;
  '⏲ Off in 15 min') timer 15 ;;
  '⏲ Off in 30 min') timer 30 ;;
  '⏲ Off in 1 hour') timer 60 ;;
  '✖️ Cancel timer') [[ -f $PID ]] && { pkill -P $(cat $PID); kill $(cat $PID); } 2>/dev/null; rm -f $PID; echo "Timer cancelled" ;;
esac
