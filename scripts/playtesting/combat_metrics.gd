class_name CombatMetrics
extends RefCounted
const DETAILS: Dictionary = {"combat_engage":["swarm","stalker"],"combat_collision":["contact"],"combat_death":["collision","swarm","stalker","other"],"combat_torpedo":["fired"],"combat_stun":["ping"],"combat_outcome":["swarm_destroyed","swarm_stunned","stalker_scared"],"combat_handling":["weighty","responsive"],"combat_rating":["weighty","about_right","sluggish","twitchy"]}
const COUNTERS: Array[String] = ["deaths","deaths_by_collision","collisions","pings","torpedoes","stun_uses","swarm_destroyed","swarm_stunned","stalker_scared"]
static func fresh() -> Dictionary:
	var result: Dictionary = {"first_engage_active_seconds":null,"profile":"weighty","profile_active_seconds":{"weighty":0.0,"responsive":0.0},"rating":"unrated"}
	for key: String in COUNTERS: result[key] = 0
	return result
static func record(metrics: Dictionary,kind: String,detail: String,active_seconds: float,amount: float) -> void:
	match kind:
		"combat_engage":
			if metrics.first_engage_active_seconds==null: metrics.first_engage_active_seconds = active_seconds
		"combat_death":
			metrics.deaths += 1
			if detail=="collision": metrics.deaths_by_collision += 1
		"combat_collision": metrics.collisions += 1
		"sonar": metrics.pings += 1
		"combat_torpedo": metrics.torpedoes += 1
		"combat_stun": metrics.stun_uses += 1
		"combat_outcome": metrics[detail] += int(amount) if detail=="swarm_stunned" else 1
		"combat_handling": metrics.profile = detail
		"combat_rating": metrics.rating = detail
static func valid(value: Variant,seconds: float) -> bool:
	if not PlaytestReport.exact(value,fresh().keys()) or value.profile not in ["weighty","responsive"] or value.rating not in ["unrated","weighty","about_right","sluggish","twitchy"]: return false
	for key: String in COUNTERS:
		if not InputBindings.is_integer(value[key]) or not PlaytestReport.number(value[key]): return false
	if value.deaths_by_collision>value.deaths or not PlaytestReport.exact(value.profile_active_seconds,["weighty","responsive"]): return false
	for key: String in ["weighty","responsive"]:
		if not PlaytestReport.number(value.profile_active_seconds[key],PlaytestReport.MAX_SECONDS): return false
	if absf(value.profile_active_seconds.weighty+value.profile_active_seconds.responsive-seconds)>0.001: return false
	return value.first_engage_active_seconds==null or PlaytestReport.number(value.first_engage_active_seconds,seconds)
static func summary(value: Dictionary,seconds: float) -> String:
	return "COMBAT TEST BOX / Hypotheses, not human results\nFirst engagement active seconds: %s\nDeaths: %d (collision: %d)\nCollisions/min: %.3f\nPings/min: %.3f\nTorpedoes: %d / Stun uses: %d\nSwarm destroyed: %d / Swarm stunned: %d / Stalker scares: %d\nHandling: %s / Active seconds by profile: %s\nPost-session rating: %s\n" % [str(value.first_engage_active_seconds),value.deaths,value.deaths_by_collision,value.collisions*60.0/maxf(seconds,0.001),value.pings*60.0/maxf(seconds,0.001),value.torpedoes,value.stun_uses,value.swarm_destroyed,value.swarm_stunned,value.stalker_scared,value.profile,JSON.stringify(value.profile_active_seconds),value.rating]
