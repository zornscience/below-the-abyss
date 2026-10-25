extends GutTest
## Deterministic harness examples; these do not implement gameplay.


func test_json_round_trip_preserves_sample_data() -> void:
	var original: Dictionary = {"label": "sample", "enabled": true}
	var decoded: Variant = JSON.parse_string(JSON.stringify(original))
	assert_eq(decoded, original, "The harness can compare structured values.")


func test_main_scene_contains_the_input_test_menu() -> void:
	var scene: PackedScene = load("res://scenes/main/main.tscn") as PackedScene
	assert_not_null(scene)
	if scene == null:
		return
	var instance: Node = autofree(scene.instantiate())
	assert_eq(String(instance.name), "GameRoot")
	assert_eq(instance.get_child_count(), 1)
	assert_true(instance.get_node("InputTestMenu") is Control)
