import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('release_safety', Path(__file__).resolve().parents[2] / 'tools/lint_release_safety.py')
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)


class ReleaseSafetyTest(unittest.TestCase):
    def test_rejects_single_and_multiline_side_effects(self):
        for source in ['assert(receiver.bind_bus(bus)==OK)', 'assert(\n receiver.bind_bus(bus)\n == OK\n)', 'assert(target.erase("id"))']:
            self.assertTrue(lint.violations(source))

    def test_ignores_comments_and_quoted_examples(self):
        self.assertEqual(lint.violations('# assert(mutate())\nvar text = "assert(mutate())"\nvar doc = """assert(\nmutate())"""'), [])

    def test_pure_checks_remain_legal(self):
        self.assertEqual(lint.violations('assert(is_finite(value) and PROFILE.is_valid())\nassert(not values.has(key))'), [])
