#!/usr/bin/env python3
"""Exercise inline native panels without changing radios, devices or connections."""
from session import ensure
ensure()
import os,subprocess,tempfile
from pathlib import Path
project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-controls-') as temporary:
    root=Path(temporary)
    for name in ['Commons','Ui']:(root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    helpers=root/'bin'
    helpers.mkdir()
    (helpers/'omarchy-audio-output-sink').write_text('#!/bin/sh\nprintf "test-output\\n"\n')
    (helpers/'tailscale').write_text("#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\nstate=Path(os.environ['ISLAND_TEST_TAILSCALE_STATE'])\nif sys.argv[1]=='status':\n    print(json.dumps({'BackendState':state.read_text() if state.exists() else 'Running'}))\nelse:\n    state.write_text('Stopped' if sys.argv[1]=='down' else 'Running')\n")
    for helper in helpers.iterdir():helper.chmod(0o755)
    (root/'shell.qml').write_text((project/'tests/Controls.qml').read_text())
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_CACHE_HOME=str(root/'cache'))
    env.update(PATH=str(helpers)+os.pathsep+env['PATH'],ISLAND_TEST_TAILSCALE_STATE=str(root/'tailscale-state'))
    env.setdefault('XDG_RUNTIME_DIR',f'/run/user/{os.getuid()}')
    for missing in [False, True]:
        run_env = dict(env)
        if missing:
            run_env.update(OMARCHY_PATH=str(root/'missing-system'), ISLAND_TEST_MISSING_SYSTEM='1')
        try:result=subprocess.run(['qs','-p',str(root),'--no-color'],env=run_env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=20)
        except subprocess.TimeoutExpired as error:
            print((error.stdout or b" ").decode());raise
        print(result.stdout)
        assert 'CONTROLS_PASS' in result.stdout and not any(x in result.stdout for x in ['CONTROLS_FAIL','FAIL!','ReferenceError:','TypeError:','Binding loop','Cannot assign','Unable to assign']),result.stdout
