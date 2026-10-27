"""Synthetic analysis fixtures only; no human study data."""
import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('analysis', Path(__file__).resolve().parents[2]/'tools/analyze_playtests.py')
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


def participant(code='P01', **changes):
    p = dict(participant_code=code, unfamiliar=True, completed=None, completion_minutes=None,
             ratings={k:None for k in a.RATINGS}, want_continue=None, navigation_difficulties=[],issues=[],share_session_id=False,session_id=None)
    p.update(changes)
    return p


def report():
    counts = {k:0 for k in a.KINDS}
    counts['session_start'] = 1
    return dict(schema_version=1,session_id='a'*32,game_version='0.1.0-playtest',build_id='source',status='active',active_seconds=2,menu_seconds=1,completed=False,completion_seconds=None,completion_active_seconds=None,counts=counts,damage_total=0,omitted_events=0,events=[dict(kind='session_start',detail='opt_in',seconds=0,amount=0)])


class AnalysisTests(unittest.TestCase):
    def test_empty_results_do_not_fabricate_people_outcomes_or_interest(self):
        result = a.analyze(dict(schema_version=1,participants=[]),[])
        self.assertEqual(result['participants'],0)
        self.assertIsNone(result['median_completion_minutes'])
        self.assertIsNone(result['chapter_completion_percent_known_outcomes'])
        self.assertIsNone(result['interested_yes_percent'])

    def test_synthetic_incomplete_outcomes_and_medians_keep_denominators(self):
        people = [participant(completed=True,completion_minutes=20,want_continue='Yes',issues=['readability']), participant('P02',completed=False,want_continue='Maybe',issues=['crash']), participant('P03')]
        result = a.analyze(dict(schema_version=1,participants=people),[])
        self.assertEqual(result['participants'],3)
        self.assertEqual(result['unknown_outcomes'],1)
        self.assertEqual(result['chapter_completion_percent_known_outcomes'],50)
        self.assertEqual(result['median_completion_minutes'],20)
        self.assertEqual(result['interested_yes_percent'],50)
        self.assertEqual(result['prioritized_review_recommendations'][0]['issue'],'crash')

    def test_sessions_are_not_people_and_link_requires_permission(self):
        result = a.analyze(dict(schema_version=1,participants=[]),[report()])
        self.assertEqual(result['participants'],0)
        self.assertEqual(result['unfinished_telemetry_sessions'],1)
        feedback = dict(schema_version=1,participants=[participant(session_id='a'*32)])
        with self.assertRaises(ValueError): a.analyze(feedback,[report()])
        feedback['participants'][0]['share_session_id'] = True
        self.assertEqual(a.analyze(feedback,[report()])['explicitly_linked_feedback'],1)

    def test_duplicate_people_and_reports_reject_instead_of_inflating_results(self):
        with self.assertRaises(ValueError): a.analyze(dict(schema_version=1,participants=[participant(),participant()]),[])
        with self.assertRaises(ValueError): a.analyze(dict(schema_version=1,participants=[]),[report(),report()])

    def test_bloom_uses_existing_event_allowlist_without_exposing_hidden_story(self):
        data = report()
        for kind, detail in [('discovery','zone1-light-bloom-habitat'), ('scan_started','zone1-light-bloom-scan'), ('scan_completed','zone1-light-bloom-scan')]:
            data['events'].append(dict(kind=kind,detail=detail,seconds=1,amount=0))
            data['counts'][kind] = 1
        a.validate_report(data)
        data['resonance'] = 15
        with self.assertRaises(ValueError): a.validate_report(data)

    def test_sunlit_progress_uses_bounded_identifiers_without_recording_dialogue(self):
        data = report()
        for kind, detail in [('discovery','sunlit-lantern1-buoy'),
                             ('scan_completed','sunlit-lantern1-buoy-record'),
                             ('mission_completed','sunlit-shallows-expedition'),
                             ('chapter_completed','the_sunlit_shallows')]:
            data['events'].append(dict(kind=kind,detail=detail,seconds=1,amount=0))
            data['counts'][kind] = 1
        data.update(completed=True,completion_seconds=1,completion_active_seconds=1)
        a.validate_report(data)
        data['events'][-1]['detail'] = "It isn't empty down there."
        with self.assertRaises(ValueError): a.validate_report(data)

    def test_malformed_or_personal_telemetry_rejected(self):
        for key, value in [('email','x'),('device_id','x'),('active_seconds',float('nan')),('events',[{'raw_key':'A'}])]:
            data = copy.deepcopy(report()); data[key] = value
            with self.assertRaises(ValueError): a.validate_report(data)
        data = report();data['events'][0]['detail'] = 'free text'
        with self.assertRaises(ValueError): a.validate_report(data)


if __name__ == '__main__': unittest.main()
