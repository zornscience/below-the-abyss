extends GutTest
## Opt-in failure demonstration. This directory is excluded from normal discovery.


func test_intentional_failure() -> void:
	assert_eq(1, 2, "Intentional BTA-003 failure: the runner must return nonzero.")
