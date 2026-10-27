#!/usr/bin/env python3
"""Analyze anonymous coded feedback and optional local sessions; never infer people from sessions."""
import argparse
import json
import math
from pathlib import Path
import statistics

RATINGS = ['enjoyment', 'objective_clarity', 'navigation', 'sonar', 'controls', 'difficulty', 'readability', 'audio', 'narrative']
NAVIGATION = ['route_finding', 'return_route', 'map', 'landmarks', 'none']
ISSUES = {
    'crash': ('critical', 'Investigate reproducible crashes and preserve affected saves.'),
    'save_load': ('critical', 'Reproduce save/Continue problems before further recruitment.'),
    'softlock': ('critical', 'Reproduce the blocked route or interface and restore a safe exit.'),
    'objective_clarity': ('major', 'Review where players first lose the expedition objective.'),
    'navigation': ('major', 'Review observed confusing landmarks and return-route guidance.'),
    'sonar': ('major', 'Review observed sonar readiness, cost and reveal feedback.'),
    'controls': ('major', 'Review observed movement/remapping/focus difficulties.'),
    'readability': ('major', 'Review the reported screen size and instrument hierarchy.'),
    'audio': ('minor', 'Review reported mix and critical visual equivalents.'),
    'narrative': ('minor', 'Review reported briefing/log comprehension without changing story prematurely.')}
KINDS = ['session_start','session_end','sonar','scan_started','scan_completed','discovery','mission_accepted','mission_completed','mission_claimed','milestone','station_return','resource_warning','damage','failure','chapter_completed','error']
DETAILS = {
    'session_start':['opt_in'], 'session_end':['disabled','quit'], 'sonar':['active_ping'],
    'scan_started':['shelf-calibration-plate','shelf-overlook-formation'], 'scan_completed':['shelf-calibration-plate','shelf-overlook-formation'],
    'discovery':['shelf-navigation-marker','shelf-overlook','shelf-twin-spires'],
    'mission_accepted':['shelf-expedition','shelf-calibration-study'], 'mission_completed':['shelf-expedition','shelf-calibration-study'], 'mission_claimed':['shelf-expedition','shelf-calibration-study'],
    'milestone':['outbound','twin_spires','returned_to_base','route_restart','continue','new_expedition'], 'station_return':['route_return'],
    'resource_warning':['hull_low','battery_low','oxygen_low','hull_depleted','battery_depleted','oxygen_depleted','depth_caution','depth_danger'],
    'damage':['impact','pressure','creature','other'], 'failure':['hull_destroyed','oxygen_depleted'], 'chapter_completed':['the_quiet_run'], 'error':['checkpoint_blocked','write_failed']}


def number(value, maximum=1e9):
    return type(value) in (int, float) and math.isfinite(value) and 0 <= value <= maximum


def integer(value):
    return number(value) and value == int(value)


def hex_id(value, length=32):
    return isinstance(value, str) and len(value) == length and all(c in '0123456789abcdef' for c in value)


def validate_report(v):
    keys = {'schema_version','session_id','game_version','build_id','status','active_seconds','menu_seconds','completed','completion_seconds','completion_active_seconds','counts','damage_total','events','omitted_events'}
    if not isinstance(v, dict) or set(v) != keys or type(v['schema_version']) is not int or v['schema_version'] != 1:
        raise ValueError('Invalid telemetry schema')
    if not hex_id(v['session_id']) or v['game_version'] != '0.1.0-playtest' or not (v['build_id'] == 'source' or hex_id(v['build_id'], 40)) or v['status'] not in ['active','disabled','quit'] or type(v['completed']) is not bool:
        raise ValueError('Invalid telemetry identity/status')
    if not all(number(v[k], 86400) for k in ['active_seconds','menu_seconds']) or v['active_seconds']+v['menu_seconds'] > 86400:
        raise ValueError('Invalid telemetry timing')
    elapsed = v['active_seconds'] + v['menu_seconds']
    if v['completed']:
        if not all(number(v[k], 86400) for k in ['completion_seconds','completion_active_seconds']) or not v['completion_active_seconds'] <= v['completion_seconds'] <= elapsed + .001:
            raise ValueError('Invalid completion timing')
    elif v['completion_seconds'] is not None or v['completion_active_seconds'] is not None:
        raise ValueError('Missing completion must remain null')
    if not isinstance(v['counts'], dict) or set(v['counts']) != set(KINDS) or not all(integer(n) for n in v['counts'].values()) or not number(v['damage_total']) or not integer(v['omitted_events']):
        raise ValueError('Invalid telemetry counters')
    if v['counts']['session_start'] != 1 or v['counts']['session_end'] != (v['status'] != 'active') or v['counts']['chapter_completed'] != v['completed']:
        raise ValueError('Inconsistent lifecycle counters')
    if not isinstance(v['events'], list) or len(v['events']) > 512 or len(v['events']) + v['omitted_events'] != sum(v['counts'].values()):
        raise ValueError('Invalid event capacity/count')
    last = 0
    for event in v['events']:
        if not isinstance(event, dict) or set(event) != {'kind','detail','seconds','amount'} or not isinstance(event['kind'],str) or event['kind'] not in DETAILS or event['detail'] not in DETAILS[event['kind']] or not number(event['seconds'],86400) or not last <= event['seconds'] <= elapsed+.001 or not number(event['amount']):
            raise ValueError('Invalid/unknown event data')
        last = event['seconds']
    return v


def validate_feedback(v):
    if not isinstance(v,dict) or set(v) != {'schema_version','participants'} or type(v['schema_version']) is not int or v['schema_version'] != 1 or not isinstance(v['participants'],list) or len(v['participants']) > 500:
        raise ValueError('Invalid feedback document')
    seen = set()
    for p in v['participants']:
        if not isinstance(p,dict) or set(p) != {'participant_code','unfamiliar','completed','completion_minutes','ratings','want_continue','navigation_difficulties','issues','share_session_id','session_id'}:
            raise ValueError('Invalid participant fields')
        code = p['participant_code']
        if not isinstance(code,str) or not 1 <= len(code) <= 16 or any(c not in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-' for c in code) or code in seen:
            raise ValueError('Invalid/duplicate anonymous participant code')
        seen.add(code)
        if type(p['unfamiliar']) is not bool or (p['completed'] is not None and type(p['completed']) is not bool) or (p['completion_minutes'] is not None and (p['completed'] is not True or not number(p['completion_minutes'],1440))):
            raise ValueError('Invalid/unknown outcome or duration')
        if not isinstance(p['ratings'],dict) or set(p['ratings']) != set(RATINGS) or any(x is not None and (type(x) is not int or x not in range(1,6)) for x in p['ratings'].values()) or p['want_continue'] not in ['Yes','Maybe','No',None]:
            raise ValueError('Invalid ratings/interest')
        for key, allowed in [('navigation_difficulties',NAVIGATION),('issues',ISSUES)]:
            if not isinstance(p[key],list) or any(not isinstance(x,str) or x not in allowed for x in p[key]) or len(set(p[key])) != len(p[key]):
                raise ValueError('Invalid coded feedback')
        if type(p['share_session_id']) is not bool or (p['share_session_id'] and not hex_id(p['session_id'])) or (not p['share_session_id'] and p['session_id'] is not None):
            raise ValueError('Linking requires explicit shared session permission')
    return v['participants']


def analyze(feedback, reports):
    participants = validate_feedback(feedback)
    sessions = {}
    for report in reports:
        validate_report(report)
        if report['session_id'] in sessions:
            raise ValueError('Duplicate telemetry session; do not count copies/backups')
        sessions[report['session_id']] = report
    known = [p for p in participants if p['completed'] is not None]
    completed = [p for p in known if p['completed']]
    times = [p['completion_minutes'] for p in completed if p['completion_minutes'] is not None]
    interest = [p for p in participants if p['want_continue'] is not None]
    nav = {k:sum(k in p['navigation_difficulties'] for p in participants) for k in NAVIGATION if k != 'none'}
    issues = {k:sum(k in p['issues'] for p in participants) for k in ISSUES}
    recommendations = [{'issue':k,'participants':n,'severity':ISSUES[k][0],'recommendation':ISSUES[k][1]} for k,n in issues.items() if n]
    recommendations.sort(key=lambda x: (['critical','major','minor'].index(x['severity']),-x['participants'],x['issue']))
    sonar = sorted(r['counts']['sonar'] for r in sessions.values())
    return {'schema_version':1,'participants':len(participants),'unfamiliar_participants':sum(p['unfamiliar'] for p in participants),
        'known_outcomes':len(known),'unknown_outcomes':len(participants)-len(known),'completed':len(completed),
        'chapter_completion_percent_known_outcomes':100*len(completed)/len(known) if known else None,
        'completion_times_measured':len(times),'median_completion_minutes':statistics.median(times) if times else None,
        'interest_responses':len(interest),'interested_yes_percent':100*sum(p['want_continue']=='Yes' for p in interest)/len(interest) if interest else None,
        'navigation_difficulties':nav,'usability_problems':issues,'prioritized_review_recommendations':recommendations,
        'telemetry_sessions':len(sessions),'unfinished_telemetry_sessions':sum(r['status']=='active' for r in sessions.values()),
        'sonar_usage_distribution':{'values':sonar,'median':statistics.median(sonar) if sonar else None,'min':min(sonar) if sonar else None,'max':max(sonar) if sonar else None},
        'explicitly_linked_feedback':sum(p['share_session_id'] and p['session_id'] in sessions for p in participants),
        'missing_consented_sessions':sum(p['share_session_id'] and p['session_id'] not in sessions for p in participants),
        'external_acceptance_status':'PENDING HUMAN EVALUATION — counts alone never certify the study or implement improvements'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--feedback',type=Path,required=True)
    parser.add_argument('--reports',type=Path,help='Directory of voluntarily shared primary *.json reports; omit for feedback only')
    parser.add_argument('--output',type=Path,required=True,help='New output JSON, never overwrites a result')
    args = parser.parse_args()
    try:
        if args.feedback.stat().st_size > 1048576:
            raise ValueError('Feedback file too large')
        reports = []
        if args.reports:
            paths = sorted(args.reports.glob('*.json'))
            if len(paths) > 500:
                raise ValueError('Too many reports')
            for path in paths:
                if path.stat().st_size > 131072:
                    raise ValueError('Report too large')
                reports.append(json.loads(path.read_text()))
        result = analyze(json.loads(args.feedback.read_text()),reports)
        with args.output.open('x') as output:
            json.dump(result,output,indent=2,allow_nan=False)
            output.write('\n')
        print(f"Analyzed {result['participants']} anonymous responses and {result['telemetry_sessions']} optional sessions. Human evaluation remains required.")
    except (ValueError,OSError,TypeError) as error:
        parser.exit(1,f'Analysis rejected: {type(error).__name__}; inputs preserved. Check the documented schema.\n')


if __name__ == '__main__':
    main()
