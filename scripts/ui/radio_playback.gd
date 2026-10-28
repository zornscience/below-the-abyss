class_name RadioPlayback
extends RefCounted
## Presentation clock only. Expiring a transmission never accepts or deletes a mission.
const CHARACTERS_PER_SECOND: float = 34.0
var text: String = ""
var elapsed: float = 0.0
var animated: bool = true

func start(body: String,animate: bool = true) -> void:
	text = body
	elapsed = 0.0
	animated = animate

func typing_seconds() -> float:
	return text.length()/CHARACTERS_PER_SECOND if animated else 0.0

func hold_seconds() -> float:
	return clampf(text.length()/15.0,6.0,18.0)

func advance(delta: float) -> Error:
	if not is_finite(delta) or delta<0: return ERR_INVALID_PARAMETER
	elapsed = minf(typing_seconds()+hold_seconds(),elapsed+delta)
	return OK

func characters() -> int:
	return mini(text.length(),floori(elapsed*CHARACTERS_PER_SECOND)) if animated else text.length()

func remaining() -> float:
	return maxf(0,typing_seconds()+hold_seconds()-elapsed)
