class_name TunnelSetProfile
extends Resource
# Resource typing avoids a Godot preload cycle through the research/save catalogues;
# TwilightTunnelCatalog.is_valid checks the concrete type before scene construction.
@export var systems: Array[Resource] = []
