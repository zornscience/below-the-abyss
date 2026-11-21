class_name DrownedCavesData
extends RefCounted
## DC-4: the first-contact site in the far chamber of the Drowned Caves. Authored facts only; the scan
## registries and the existing mission-free research list own progress. Four records: Mara's required
## chamber log, the paintings, the glyph wall (Wick's simple translation and the Vow of Silence) and one
## optional Mara log in the squeeze's blind pocket. No research points, no experience, no mission.
## EVERY LINE OF TEXT BELOW IS NEW AND AWAITS DESIGNER EDITING. It stays within what the Story Bible
## (page 6) states: ancient human handprints and paintings of tall glowing figures and a battle, Vael
## glyphs telling the same story, Mara realising the Choir is a language, Wick reading simple glyphs,
## and the Vow of Silence. The Bible leaves the glyph vocabulary open; three plain meanings are proposed.
const MARA_LOG_ONE: StringName = &"caves-mara-log-one"
const MARA_LOG_TWO: StringName = &"caves-mara-log-two"
const PAINTINGS: StringName = &"caves-paintings"
const GLYPH_WALL: StringName = &"caves-glyph-wall"
## The only required record. The others are optional codex entries.
const REQUIRED: StringName = MARA_LOG_ONE
static func records() -> Array[Dictionary]:
	var profile: TunnelProfile = DrownedCavesLayout.TUNNELS.systems[0] as TunnelProfile
	var far: Vector2 = DrownedCavesLayout.FAR_CHAMBER
	return [
		{"id":String(PAINTINGS),"title":"Cave paintings / first contact","at":far+Vector2(-1400,-700),"type":"artificial","source":"Wick",
			"text":"Ancient handprints in pale pigment ring the chamber wall, pressed by many hands. Above them, painted figures stand taller than the people beside them, outlined in a pigment that still holds a faint glow. One scene shows the two groups facing each other. The next shows them in a struggle.\n\nWick: The pigment is far older than anything we have dated on the shelf. The scenes do not say who began it.\n\nOkafor: Keep the order of the scenes. Do not clean the wall."},
		{"id":String(GLYPH_WALL),"title":"Vael glyph wall / the other side","at":far+Vector2(800,-700),"type":"artificial","source":"Wick",
			"text":"Pale glyphs run along the wall beside the paintings, in the same order as the scenes. They are light-writing: patterns that glow where the rock was cut.\n\nWick: I can read three marks. Silence. Deep water. Withdrawal. The same three repeat after the struggle, over and over, as if they were being sworn. I think this is a vow rather than a description: a Vow of Silence. I do not know who it was made to, or what it cost them.\n\nOkafor: Record the spacing between the marks."},
		{"id":String(MARA_LOG_ONE),"title":"Mara / field log 04","at":far+Vector2(1100,450),"type":"artificial","source":"Mara",
			"text":"Mara Voss / recovered survey instrument\n\nI found the wall and sat in front of it until my lamp dimmed. The marks beside the paintings repeat in the order of the song I have been recording for months. I called it noise. It is not noise. It is a language, and the wall is the same story told twice, once by each side.\n\nI am going to stop calling the Choir a sound. Elias will not like how little I can prove. I think he will believe it anyway.\n\nI left this recorder where the next person would find it. If that is you: do not clean the wall."},
		{"id":String(MARA_LOG_TWO),"title":"Mara / field log 05 (optional)","at":profile.origin+profile.branch[-1],"type":"artificial","source":"Mara",
			"text":"Mara Voss / detached logger\n\nThe squeeze took more air than I planned. I stopped in this pocket and shut everything off to listen. The song was closer here, and slower, as if it were being said carefully for someone still learning it.\n\nI counted my breaths so I would not count the oxygen. Then I went on."}]
static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item: Dictionary in records(): result.append(StringName(item.id))
	return result
static func knows(id: StringName) -> bool:
	return id in ids()
static func record(id: StringName) -> Dictionary:
	for item: Dictionary in records():
		if StringName(item.id)==id: return item.duplicate(true)
	return {}
