"""One success contract for finite QML scenarios and gallery captures."""
import re


def assert_qml_pass(result, marker):
    output = (result.stdout or '') + (result.stderr or '')
    errors = ('FAIL!', 'ERROR:', 'ReferenceError:', 'TypeError:', 'SyntaxError:', 'RangeError:',
              'Binding loop', 'Cannot assign', 'Unable to assign', 'recursive rearrange',
              'Error compiling', 'Failed to build graphics pipeline')
    failure = re.search(r'\b[A-Z][A-Z0-9_]*_(?:FAIL|TIMEOUT)\b', output)
    passed = re.search(r'(?<!\w)' + re.escape(marker) + r'(?!\w)', output)
    if result.returncode != 0 or not passed or failure or any(error in output for error in errors):
        raise AssertionError(f'QML scenario {marker}: exit {result.returncode}\n{output}')
