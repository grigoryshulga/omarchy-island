#!/usr/bin/env python3
"""Real QML weather service with a deterministic provider and an isolated home."""
from qml_result import assert_qml_pass
from session import ensure
ensure()
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-weather-service-') as temporary:
    root=Path(temporary)
    for module in ['Commons','Ui']:(root/module).symlink_to(Path('/usr/share/omarchy/shell')/module)
    module=root/'Weather';(module/'bin').mkdir(parents=True)
    for name in ['WeatherService.qml','WeatherModel.js']:shutil.copy2(project/'plugin'/name,module/name)
    home=root/'home';state=home/'.local/state/omarchy/island';state.mkdir(parents=True)
    location=home/'.local/state/omarchy/settings/weather.json';location.parent.mkdir(parents=True)
    location.write_text('{"name":"First City","latitude":48,"longitude":16}')
    (module/'bin/weather-data').write_text('''import json,pathlib,sys,time
home=pathlib.Path.home()
if sys.argv[1]=='search':
    query=sys.argv[2]
    if query=='slow':
        import signal
        signal.signal(signal.SIGTERM,signal.SIG_IGN)
        (home/'slow-started').write_text('started')
        time.sleep(0.3)
    if query=='error':sys.exit(1)
    rows=[] if query=='empty' else [{'name':query,'latitude':48,'longitude':16}]
    print(json.dumps({'query':query,'results':rows}))
    sys.exit(0)
time.sleep(0.08)
flag=home/'failure'
if flag.exists() and flag.read_text().strip():sys.exit(1)
place=json.loads((home/'.local/state/omarchy/settings/weather.json').read_text())
print(json.dumps({'location':place,'fetchedAt':int(time.time()),'forecast':{'current':{'temperature_2m':7,'weather_code':63,'is_day':1},'daily':{}}}))
''')
    (root/'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "Weather" as Weather
ShellRoot {
  property int stage: 0
  Weather.WeatherService {id:weather;Component.onCompleted:activate()}
  Weather.WeatherService {id:blocked;allowed:false;Component.onCompleted:activate()}
  FileView {id:started;path:Quickshell.env("HOME")+"/slow-started";watchChanges:true;printErrors:false;onFileChanged:reload()}
  FileView {id:flag;path:Quickshell.env("HOME")+"/failure";printErrors:false}
  Timer {interval:50;running:true;repeat:true;onTriggered:{
    if(stage===0 && weather.report && !weather.loading) {
      if(weather.report.location!=="First City" || blocked.activated) {console.log("WEATHER_SERVICE_FAIL startup");Qt.quit();return}
      weather.choose({name:"Next City",latitude:49,longitude:17});stage=1
    } else if(stage===1 && weather.report && weather.report.location==="Next City" && !weather.loading) {
      flag.setText("fail");stage=2
    } else if(stage===2 && flag.text()==="fail") {weather.refresh();stage=3}
    else if(stage===3 && !weather.loading && weather.error!=="") {
      if(weather.report.location!=="Next City" || !weather.stale)console.log("WEATHER_SERVICE_FAIL stale data")
      weather.search("empty");stage=4
    } else if(stage===4 && weather.searchStatus==="empty") {
      weather.search("error");stage=5
    } else if(stage===5 && weather.searchStatus==="error") {
      weather.search("slow");stage=6
    } else if(stage===6 && started.text()==="started") {
      weather.search("fresh");stage=7
    } else if(stage===7 && weather.searchStatus==="found") {
      stage=8;settle.start()
    }
  }}
  Timer {id:settle;interval:450;onTriggered:{
    if(weather.suggestions.length===1 && weather.suggestions[0].name==="fresh") console.log("WEATHER_SERVICE_PASS")
    else console.log("WEATHER_SERVICE_FAIL stale search")
    Qt.quit()
  }}
  Timer {interval:4500;running:true;onTriggered:{console.log("WEATHER_SERVICE_FAIL timeout",weather.error);Qt.quit()}}
}
''')
    env=dict(os.environ,HOME=str(home),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
    result=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,capture_output=True,text=True,timeout=6)
    output=result.stdout+result.stderr
    assert_qml_pass(result, 'WEATHER_SERVICE_PASS')
    assert (state/'weather.json').is_file(),'Weather cache missing'
print('PASS: weather startup, native city changes, disabled networking and last-good data on failure.')
