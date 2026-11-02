class_name TwilightSentinel
extends AcousticCreature
## Same acoustic receiver/navigation as wildlife; entanglement prevents translation.
var released: bool = false
func advance_simulation(delta: float) -> Error:
	if not released:
		if not is_finite(delta) or delta<0: return ERR_INVALID_PARAMETER
		velocity = Vector2.ZERO
		return OK
	return super.advance_simulation(delta)
