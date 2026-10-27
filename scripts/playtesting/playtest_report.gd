class_name PlaytestReport
extends RefCounted
## Privacy allowlist and bounded data contract. No free text, input, pose or OS data.
const MAX_EVENTS: int = 512
const MAX_BYTES: int = 131072
const MAX_SECONDS: float = 86400.0
const DETAILS: Dictionary = {
	"session_start": ["opt_in"], "session_end": ["disabled", "quit"],
	"sonar": ["active_ping"], "scan_started": ["shelf-calibration-plate", "shelf-overlook-formation", "outer-hydrophone-record", "outer-vent-study", "lost-expedition-blackbox", "observer-ecology"],
	"scan_completed": ["shelf-calibration-plate", "shelf-overlook-formation", "outer-hydrophone-record", "outer-vent-study", "lost-expedition-blackbox", "observer-ecology"],
	"discovery": ["shelf-navigation-marker", "shelf-twin-spires", "shelf-overlook", "outer-hydrophone", "outer-vent-garden", "lost-expedition-wreck", "observer-habitat"],
	"mission_accepted": ["shelf-expedition", "shelf-calibration-study", "shelf-outer-search", "shelf-wreck-recovery", "shelf-wildlife-study"],
	"mission_completed": ["shelf-expedition", "shelf-calibration-study", "shelf-outer-search", "shelf-wreck-recovery", "shelf-wildlife-study"],
	"mission_claimed": ["shelf-expedition", "shelf-calibration-study", "shelf-outer-search", "shelf-wreck-recovery", "shelf-wildlife-study"],
	"milestone": ["outbound", "twin_spires", "returned_to_base", "route_restart", "continue", "new_expedition"],
	"station_return": ["route_return"], "resource_warning": ["hull_low", "battery_low", "oxygen_low", "hull_depleted", "battery_depleted", "oxygen_depleted", "depth_caution", "depth_danger"],
	"damage": ["impact", "pressure", "creature", "other"],
	"failure": ["hull_destroyed", "oxygen_depleted"],
	"chapter_completed": ["the_quiet_run"], "error": ["checkpoint_blocked", "write_failed"]}


static func number(value: Variant, maximum: float = 1000000000.0) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= maximum


static func exact(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true


static func hex_id(value: Variant, size: int) -> bool:
	if not value is String or value.length() != size:
		return false
	for character: String in value:
		if not character in "0123456789abcdef":
			return false
	return true


static func valid(value: Variant) -> bool:
	if not exact(value, ["schema_version", "session_id", "game_version", "build_id", "status", "active_seconds", "menu_seconds", "completed", "completion_seconds", "completion_active_seconds", "counts", "damage_total", "events", "omitted_events"]):
		return false
	if value.schema_version != 1 or not InputBindings.is_integer(value.schema_version) or not hex_id(value.session_id, 32) \
		or value.game_version != "0.1.0-playtest" or (value.build_id != "source" and not hex_id(value.build_id, 40)) \
		or value.status not in ["active", "disabled", "quit"] or not value.completed is bool:
		return false
	if not number(value.active_seconds, MAX_SECONDS) or not number(value.menu_seconds, MAX_SECONDS) or value.active_seconds + value.menu_seconds > MAX_SECONDS:
		return false
	if value.completed:
		if not number(value.completion_seconds, MAX_SECONDS) or not number(value.completion_active_seconds, MAX_SECONDS) \
			or value.completion_active_seconds > value.completion_seconds or value.completion_seconds > value.active_seconds + value.menu_seconds + 0.001:
			return false
	elif value.completion_seconds != null or value.completion_active_seconds != null:
		return false
	if not exact(value.counts, DETAILS.keys()) or not number(value.damage_total) or not InputBindings.is_integer(value.omitted_events) or not number(value.omitted_events):
		return false
	var total: int = 0
	for kind: String in DETAILS:
		if not InputBindings.is_integer(value.counts[kind]) or not number(value.counts[kind]):
			return false
		total += int(value.counts[kind])
	if value.counts.session_start != 1 or value.counts.session_end != (0 if value.status == "active" else 1) or value.counts.chapter_completed != (1 if value.completed else 0):
		return false
	if not value.events is Array or value.events.size() > MAX_EVENTS or value.events.size() + value.omitted_events != total:
		return false
	var previous: float = 0.0
	for event: Variant in value.events:
		if not exact(event, ["kind", "detail", "seconds", "amount"]) or not event.kind is String or not DETAILS.has(event.kind) or event.detail not in DETAILS[event.kind] \
			or not number(event.seconds, MAX_SECONDS) or event.seconds < previous or event.seconds > value.active_seconds + value.menu_seconds + 0.001 or not number(event.amount):
			return false
		previous = float(event.seconds)
	return JSON.stringify(value).length() <= MAX_BYTES


static func summary(value: Dictionary) -> String:
	if not valid(value):
		return "Invalid playtest report. Original file preserved."
	var text: String = "BELOW THE ABYSS / Anonymous local playtest\nSession: %s\nVersion: %s / Build: %s\nStatus: %s\nChapter completed this session: %s\nActive gameplay seconds: %.3f\nMenus/paused seconds: %.3f\nCompletion seconds (from opt-in): %s\n" % [value.session_id, value.game_version, value.build_id, "INTERRUPTED / unfinished checkpoint" if value.status == "active" else value.status, value.completed, value.active_seconds, value.menu_seconds, str(value.completion_seconds)]
	for kind: String in DETAILS:
		text += "%s: %d\n" % [kind, value.counts[kind]]
	text += "Hull damage total: %.3f\nEvents omitted after bounded history filled: %d\n" % [value.damage_total, value.omitted_events]
	for event: Dictionary in value.events:
		text += "%.3fs / %s / %s / %.3f\n" % [event.seconds, event.kind, event.detail, event.amount]
	return text
