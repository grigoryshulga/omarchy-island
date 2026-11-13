"""Shared offscreen host, storage and process-fixture setup for module scenarios."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]


class ModuleHarness:
    def __enter__(self):
        if not os.environ.get('ISLAND_TEST_SESSION'):
            raise RuntimeError('Module scenarios must enter through bin/test-session')
        self.temporary = tempfile.TemporaryDirectory(prefix='island-modules-')
        self.root = Path(self.temporary.name)
        for name in ('Commons', 'Ui'):
            (self.root / name).symlink_to(Path('/usr/share/omarchy/shell') / name)
        shutil.copytree(PROJECT / 'plugin', self.root / 'Island')
        shutil.copy2(PROJECT / 'tests/ModuleHost.qml', self.root / 'ModuleHost.qml')
        self.storage = self.root / 'storage'
        self.storage.mkdir(mode=0o700)
        return self

    def __exit__(self, *exception):
        self.temporary.cleanup()

    def register(self, name, files):
        shutil.copytree(files, self.root / 'Island/modules' / name)
        with (self.root / 'Island/ModuleCatalog.mjs').open('a') as catalog:
            catalog.write(f'\nimport {name} from "./modules/{name}/Module.mjs";\ndefinitions.push({name});\n')

    def run(self, scenario, marker, variables=None):
        (self.root / 'shell.qml').write_text(scenario.read_text())
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                   ISLAND_MODULE_STORAGE=str(self.storage),
                   ISLAND_MODULE_HELPER=str(PROJECT / "tests/modules/watch-downloads-fixture.py"))
        env.update(variables or {})
        result = subprocess.run(['qs', '-p', str(self.root), '--no-color'], env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=12)
        print(result.stdout)
        assert result.returncode == 0 and marker in result.stdout and not any(error in result.stdout for error in
            ['MODULES_FAIL', 'FAIL!', 'TypeError:', 'ReferenceError:', 'Binding loop', 'Cannot assign', 'Unable to assign'])
