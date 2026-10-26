class_name ContinentalShelf
extends DepthRegion
## Authored region metadata; terrain and route markers are editable scene nodes.

@export var camera_bounds: Rect2i = Rect2i(0, 0, 4100, 1800)
@onready var spawn: Marker2D = $StationSpawn
@onready var base_zone: GrayboxRouteZone = $BaseZone
@onready var point_of_interest_zone: GrayboxRouteZone = $PointOfInterestZone


func configure_camera(camera: Camera2D) -> void:
	camera.limit_left = camera_bounds.position.x
	camera.limit_top = camera_bounds.position.y
	camera.limit_right = camera_bounds.end.x
	camera.limit_bottom = camera_bounds.end.y
