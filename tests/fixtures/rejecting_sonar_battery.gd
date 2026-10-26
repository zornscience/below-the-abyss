class_name RejectingSonarBattery
extends SubmarineResourceSystem
## Simulates a failed final cost despite a successful earlier readiness query.


func try_consume_battery(_amount: float) -> bool:
	return false
