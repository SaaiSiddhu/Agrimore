#!/usr/bin/env python3
"""F0.1: exercise the real gate with isolated, deterministic tool executables.

No Firebase, SDK, provider or application execution. The fake npm only permits
the quick gate's build command; Flutter emits representative completion/failure
logs. This catches false success when analysis never ran, not app correctness.
"""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GATE = ROOT / '.claude/skills/agrimore/scripts/gate.sh'
CASES = [
    ('completed-clean', 0, 'Analyzing employee...\nNo issues found! (ran in 1.0s)\n', True),
    ('completed-info', 1, 'Analyzing employee...\n   info • Use a const constructor • lib/a.dart:1:1 • prefer_const_constructors\n1 issue found. (ran in 1.0s)\n', True),
    ('completed-warning', 1, 'Analyzing employee...\nwarning • Unused field • lib/a.dart:1:1 • unused_field\n1 issue found. (ran in 1.0s)\n', True),
    ('completed-error', 1, 'Analyzing employee...\n  error • Undefined name • lib/a.dart:1:1 • undefined_identifier\n1 issue found. (ran in 1.0s)\n', False),
    ('sdk-permission-failure', 1, 'update_engine_version.sh: engine.stamp: Operation not permitted\n', False),
    ('tool-crash', 2, 'Flutter terminated unexpectedly.\n', False),
    ('inconsistent-exit', 1, 'Analyzing employee...\nNo issues found! (ran in 1.0s)\n', False),
    ('empty-output', 0, '', False),
    ('incomplete-output', 1, 'Analyzing employee...\n   info • One diagnostic before a crash • lib/a.dart:1:1 • prefer_const_constructors\n', False),
    ('unparsed-diagnostics', 1, 'Analyzing employee...\nUnexpected future diagnostic format\n2 issues found. (ran in 1.0s)\n', False),
]

def main():
    failures = []
    with tempfile.TemporaryDirectory(prefix='agrimore-f0-gate-') as temporary:
        folder = Path(temporary)
        tools = folder / 'tools'
        tools.mkdir()
        (tools / 'npm').write_text('#!/bin/sh\n[ "$1" = run ] && [ "$2" = build ]\n')
        (tools / 'flutter').write_text('#!/bin/sh\ncat "$AGRIMORE_ANALYSIS_FIXTURE"\nexit "$AGRIMORE_ANALYSIS_EXIT"\n')
        for executable in tools.iterdir():
            executable.chmod(0o755)
        for name, tool_exit, output, expected_pass in CASES:
            fixture = folder / (name + '.log')
            fixture.write_text(output)
            environment = dict(os.environ)
            environment.update({
                'PATH': str(tools) + os.pathsep + environment['PATH'],
                'AGRIMORE_ANALYSIS_FIXTURE': str(fixture),
                'AGRIMORE_ANALYSIS_EXIT': str(tool_exit),
                'AGRIMORE_GATE_OUT': str(folder / name),
            })
            result = subprocess.run(['bash', str(GATE), '--quick', '--apps', 'employee'],
                                    cwd=ROOT, env=environment, text=True, capture_output=True)
            passed = result.returncode == 0
            if passed != expected_pass:
                failures.append(name)
                print('FAIL', name, 'gate_exit=' + str(result.returncode))
            else:
                print('PASS', name, 'gate_exit=' + str(result.returncode))
    print('Scenarios:', len(CASES), 'passed:', len(CASES) - len(failures), 'failed:', len(failures))
    return 1 if failures else 0

if __name__ == '__main__':
    raise SystemExit(main())
