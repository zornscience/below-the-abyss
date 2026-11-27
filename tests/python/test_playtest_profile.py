"""Rules of tools/build_playtest_profile.py that need no Godot run. Synthetic saves only."""
import copy
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
spec = importlib.util.spec_from_file_location('build_playtest_profile', ROOT / 'tools/build_playtest_profile.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


def dock_save(bloom='zone1-light-bloom-collect', sentinel='zone2-sentinel-release'):
    return {
        'format': 'bta-expedition', 'schema_version': 10, 'region_id': 'continental_shelf',
        'journey': {'commissioned': True, 'phase': 'refit'},
        'story': {'decisions': [bloom, sentinel], 'flags': [], 'resonance': 0},
        'prototype': {'ammunition': 10, 'campaign': {'awards': ['commission', 'twilight-expedition'],
                                                     'ranks': {'hull': 0, 'sonar': 1, 'engine': 0}}},
        'progress': {'research': ['twilight-net-survey', 'sunlit-silver-shoal']},
        'player': {}, 'route': {}, 'terrain': [], 'legacy_conclusion': False, 'legacy_imported': True,
    }


class ProfileTests(unittest.TestCase):
    def test_a_dock_checkpoint_with_the_requested_choices_is_accepted(self):
        self.assertEqual(len(dock_save()), p.SCHEMA_FIELDS)
        p.validate_profile(dock_save(), 'collect', 'release')
        p.validate_profile(dock_save('zone1-light-bloom-observe', 'zone2-sentinel-capture'), 'observe', 'capture')

    def test_a_checkpoint_left_at_the_twilight_tether_is_rejected(self):
        save = dock_save()
        save['journey']['phase'] = 'twilight'
        with self.assertRaisesRegex(ValueError, 'not at the Halcyon dock'):
            p.validate_profile(save, 'collect', 'release')

    def test_choices_other_than_the_requested_ones_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'zone2-sentinel-capture'):
            p.validate_profile(dock_save(), 'collect', 'capture')
        with self.assertRaisesRegex(ValueError, 'zone1-light-bloom-observe'):
            p.validate_profile(dock_save(), 'observe', 'release')

    def test_an_unclaimed_debrief_is_rejected(self):
        save = dock_save()
        save['prototype']['campaign']['awards'] = ['commission']
        with self.assertRaisesRegex(ValueError, 'debrief'):
            p.validate_profile(save, 'collect', 'release')

    def test_another_schema_version_or_field_count_is_rejected(self):
        save = dock_save()
        save['schema_version'] = 11
        with self.assertRaisesRegex(ValueError, 'schema'):
            p.validate_profile(save, 'collect', 'release')
        save = dock_save()
        save['extra'] = 1
        with self.assertRaisesRegex(ValueError, 'schema'):
            p.validate_profile(save, 'collect', 'release')

    def test_the_lost_sentinel_outcome_is_not_offered(self):
        self.assertNotIn('lost', p.SENTINEL)

    def test_the_manifest_reports_ranks_and_sorted_research_and_says_it_is_scripted(self):
        details = p.manifest(dock_save(), 'collect', 'release', 'abc123')
        self.assertEqual(details['ranks']['hull'], 0)
        self.assertEqual(details['research'], ['sunlit-silver-shoal', 'twilight-net-survey'])
        self.assertIn('not human play', details['built_by'])
        self.assertEqual(details['source_commit'], 'abc123')

    def test_the_settings_and_evidence_variables_are_isolated(self):
        env = p.xdg(Path('/x'))
        self.assertEqual(env['XDG_DATA_HOME'], '/x/data')
        self.assertNotIn('BTA_EVIDENCE_DIR', env)

    def test_a_non_empty_output_folder_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'keep.txt').write_text('participant data')
            with self.assertRaisesRegex(RuntimeError, 'not empty'):
                p.build('collect', 'release', Path(folder))
            self.assertEqual((Path(folder) / 'keep.txt').read_text(), 'participant data')


if __name__ == '__main__':
    unittest.main()
