#!/usr/bin/env python3
import json,os,shutil,subprocess,tempfile
from pathlib import Path
project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-indicators-') as temporary:
    home=Path(temporary);config=home/'.config/omarchy/shell.json';config.parent.mkdir(parents=True)
    original={'bar':{'layout':{'centerBegin':[{'id':'omarchy.indicators'}],'right':[{'id':'omarchy.audio'},{'id':'omarchy.keyboard-layout','format':'short'}]}},'plugins':[{'id':'other.plugin'}],'disabledPlugins':[]}
    config.write_text(json.dumps(original));env=dict(os.environ,HOME=str(home))
    def run(*args):subprocess.run(['python3',str(project/'plugin/bin/configure-indicators'),*args],env=env,check=True,stdout=subprocess.PIPE,text=True)
    run();one=json.loads(config.read_text())
    assert one['bar']['layout']['centerBegin'][0]['items']==['PasswordlessSudo','Reminder']
    assert one['bar']['layout']['right']==[{'id':'omarchy.audio'}]
    assert 'omarchy.osd' in one['disabledPlugins'] and any(p['id']=='gshulga.island-osd' for p in one['plugins'])
    assert (home/'.config/omarchy/plugins/gshulga.island-osd/Panel.qml').is_file()
    run();assert json.loads(config.read_text())==one
    run('--disable');restored=json.loads(config.read_text())
    assert restored['bar']==original['bar'] and restored['plugins']==original['plugins']
    assert 'omarchy.osd' not in restored['disabledPlugins']
    # A group containing only migrated indicators must not revert to all stock items.
    (home/'.local/state/omarchy/island/indicators-install.json').unlink()
    original['bar']['layout']['centerBegin'][0]['items']=['Dnd','StayAwake']
    config.write_text(json.dumps(original))
    shutil.rmtree(home/'.config/omarchy/plugins/gshulga.island-osd')
    run();assert not json.loads(config.read_text())['bar']['layout']['centerBegin']
    run('--disable');assert json.loads(config.read_text())['bar']==original['bar']
print('PASS: OSD adapter installation, idempotence, indicator migration and restoration.')
