#!/usr/bin/env python3
"""Build Bulb.shortcut: Choose from List -> Run Shell Script (UDP straight to the bulb, no server).
Edit MENU, run `python3 make_shortcut.py`, then `open Bulb.shortcut` to (re)import."""
import plistlib, subprocess, uuid
from pathlib import Path

BULB = "192.168.1.34"
MENU = {  # label -> setPilot params
    "💡 On": '"state":true',
    "⚫ Off": '"state":false',
    "🔆 Warm white": '"state":true,"temp":2700,"dimming":100',
    "☀️ Neutral": '"state":true,"temp":4200,"dimming":100',
    "🌤 Daylight": '"state":true,"temp":6500,"dimming":100',
    "🌙 Night light": '"state":true,"sceneId":14',
    "🔅 Brightness 10%": '"state":true,"dimming":10',
    "🔅 Brightness 25%": '"state":true,"dimming":25',
    "🔆 Brightness 50%": '"state":true,"dimming":50',
    "🔆 Brightness 75%": '"state":true,"dimming":75',
    "🔆 Brightness 100%": '"state":true,"dimming":100',
    "🔴 Red": '"state":true,"r":255,"g":0,"b":0',
    "🟠 Orange": '"state":true,"r":255,"g":90,"b":0',
    "🩷 Pink": '"state":true,"r":255,"g":20,"b":120',
    "🟣 Purple": '"state":true,"r":140,"g":0,"b":255',
    "🔵 Blue": '"state":true,"r":0,"g":40,"b":255',
    "🟢 Green": '"state":true,"r":0,"g":255,"b":40',
    "🛋 Cozy": '"state":true,"sceneId":6',
    "🔥 Fireplace": '"state":true,"sceneId":5',
    "🌅 Sunset": '"state":true,"sceneId":3',
    "🌊 Ocean": '"state":true,"sceneId":1',
    "🎉 Party": '"state":true,"sceneId":4',
    "🧘 Relax": '"state":true,"sceneId":16',
    "🎯 Focus": '"state":true,"sceneId":15',
    "📺 TV time": '"state":true,"sceneId":18',
    "🕯 Candlelight": '"state":true,"sceneId":29',
}
TIMERS = {"⏲ Off in 15 min": 15, "⏲ Off in 30 min": 30, "⏲ Off in 1 hour": 60}

cases = "\n".join(f"  {label!r}) send '{p}' ;;" for label, p in MENU.items())
cases += "\n" + "\n".join(f"  {label!r}) timer {m} ;;" for label, m in TIMERS.items())
SCRIPT = f"""B={BULB}; PID=/tmp/wiz-timer.pid
send() {{ r=$(echo -n "{{\\"method\\":\\"setPilot\\",\\"params\\":{{$1}}}}" | nc -u -w 1 $B 38899)
  [[ $r == *success* ]] || {{ echo "Bulb didn't answer: $r"; exit 1; }}; }}
timer() {{ [[ -f $PID ]] && {{ pkill -P $(cat $PID); kill $(cat $PID); }} 2>/dev/null
  nohup sh -c "sleep $(($1*60)); echo -n '{{\\"method\\":\\"setPilot\\",\\"params\\":{{\\"state\\":false}}}}' | nc -u -w 1 $B 38899; rm -f $PID" >/dev/null 2>&1 &
  echo $! > $PID; echo "Off in $1 min"; }}
case "$(cat)" in
{cases}
  '✖️ Cancel timer') [[ -f $PID ]] && {{ pkill -P $(cat $PID); kill $(cat $PID); }} 2>/dev/null; rm -f $PID; echo "Timer cancelled" ;;
esac
"""

labels = [*MENU, *TIMERS, "✖️ Cancel timer"]
list_id, choose_id = str(uuid.uuid4()).upper(), str(uuid.uuid4()).upper()
ref = lambda uid, name: {"Value": {"OutputUUID": uid, "Type": "ActionOutput", "OutputName": name},
                         "WFSerializationType": "WFTextTokenAttachment"}
text = lambda s: {"WFItemType": 0, "WFValue": {"Value": {"string": s, "attachmentsByRange": {}},
                                              "WFSerializationType": "WFTextTokenString"}}
workflow = {
    "WFWorkflowClientVersion": "2605.0.5",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4292093695, "WFWorkflowIconGlyphNumber": 59511},
    "WFWorkflowImportQuestions": [], "WFWorkflowTypes": ["MenuBar"], "WFWorkflowInputContentItemClasses": [],
    "WFWorkflowActions": [
        {"WFWorkflowActionIdentifier": "is.workflow.actions.list",
         "WFWorkflowActionParameters": {"UUID": list_id, "WFItems": [text(l) for l in labels]}},
        {"WFWorkflowActionIdentifier": "is.workflow.actions.choosefromlist",
         "WFWorkflowActionParameters": {"UUID": choose_id, "WFChooseFromListActionPrompt": "Bulb",
                                        "WFInput": ref(list_id, "List")}},
        {"WFWorkflowActionIdentifier": "is.workflow.actions.runshellscript",
         "WFWorkflowActionParameters": {"Script": SCRIPT, "Shell": "/bin/zsh", "InputMode": "to stdin",
                                        "Input": ref(choose_id, "Chosen Item")}},
    ],
}

if __name__ == "__main__":
    here = Path(__file__).parent
    Path(here / "bulb.sh").write_text(SCRIPT)  # same script, for testing: echo "🔴 Red" | zsh bulb.sh
    raw = here / "Bulb.unsigned.shortcut"
    raw.write_bytes(plistlib.dumps(workflow, fmt=plistlib.FMT_BINARY))
    subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", raw, "--output", here / "Bulb.shortcut"], check=True)
    raw.unlink()
    print("built", here / "Bulb.shortcut")
