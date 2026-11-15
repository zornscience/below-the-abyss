class_name VesselRecoveryProfile
extends Resource
## Designer-tuned life-support grace after oxygen reaches zero. Authored values only.
## Recovery itself is a free full restock at Halcyon. There is no restore fraction.

## Simulation seconds between oxygen reaching zero and Halcyon recovery.
@export_range(0.001, 3600.0) var grace_seconds: float = 60.0


func is_valid() -> bool:
	return is_finite(grace_seconds) and grace_seconds > 0.0
