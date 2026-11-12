#!/usr/bin/env python3
"""Exercise calendar navigation in real QML; report timings and guard reuse/focus."""
import argparse
import io
import os
import subprocess
import tarfile
import tempfile
from pathlib import Path

project = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--baseline-ref", help="Measure committed sources without altering the checkout")
parser.add_argument("--measure-only", action="store_true", help="Report timings without asserting new behavior")
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix="island-performance-") as temporary:
    root = Path(temporary)
    for name in ["Commons", "Ui"]:
        (root / name).symlink_to(Path("/usr/share/omarchy/shell") / name)
    plugin = project / "plugin"
    if args.baseline_ref:
        archive = subprocess.check_output(["git", "archive", "--format=tar", args.baseline_ref, "--", "plugin"], cwd=project)
        with tarfile.open(fileobj=io.BytesIO(archive)) as source:
            source.extractall(root / "baseline", filter="data")
        plugin = root / "baseline/plugin"
    (root / "Island").symlink_to(plugin)
    (root / "shell.qml").write_text((project / "tests/Performance.qml").read_text())
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
    if args.baseline_ref or args.measure_only:
        env["ISLAND_PERF_MEASURE_ONLY"] = "1"
    try:
        result = subprocess.run(["qs", "-p", str(root), "--no-color"], env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=30)
    except subprocess.TimeoutExpired as error:
        print((error.stdout or b"").decode())
        raise
    print(result.stdout)
    assert "PERFORMANCE_PASS" in result.stdout and not any(
        error in result.stdout for error in ["FAIL!", "ReferenceError:", "TypeError:",
                                            "Binding loop", "Cannot assign", "Unable to assign"]
    ), result.stdout
