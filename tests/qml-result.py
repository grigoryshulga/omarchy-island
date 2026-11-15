#!/usr/bin/env python3
"""Ensure test runners cannot report success after a QML failure or crash."""
from subprocess import CompletedProcess
import unittest
from qml_result import assert_qml_pass


class QmlResultTests(unittest.TestCase):
    def test_success_with_platform_warning(self):
        assert_qml_pass(CompletedProcess([], 0, 'DEBUG qml: SCENARIO_PASS\n',
                                        'WARN: This plugin does not support setting window masks\n'),
                        'SCENARIO_PASS')

    def test_missing_or_partial_marker(self):
        for output in ('', 'SCENARIO_PASS_EXTRA', 'NOT_SCENARIO_PASS'):
            with self.subTest(output=output), self.assertRaises(AssertionError):
                assert_qml_pass(CompletedProcess([], 0, output, ''), 'SCENARIO_PASS')

    def test_failure_wins_over_success(self):
        for code, error in ((1, ''), (-11, ''), (0, 'SCENARIO_FAIL'),
                            (0, 'OTHER_SCENARIO_FAIL'), (0, 'SCENARIO_TIMEOUT'),
                            (0, 'FAIL! : compare'), (0, 'TypeError: missing property'),
                            (0, 'ReferenceError: missing object'), (0, 'Binding loop detected'),
                            (0, 'Failed to build graphics pipeline')):
            for stream in ('stdout', 'stderr'):
                with self.subTest(code=code, error=error, stream=stream), self.assertRaises(AssertionError):
                    result = CompletedProcess([], code, 'SCENARIO_PASS\n', '')
                    setattr(result, stream, getattr(result, stream) + error)
                    assert_qml_pass(result, 'SCENARIO_PASS')


if __name__ == '__main__':
    unittest.main()
