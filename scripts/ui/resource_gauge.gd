class_name ResourceGauge
extends PanelContainer
## Read-only presentation. Values and maxima are supplied by domain components.

@export var caption: String = "HULL INTEGRITY"
@export var glyph: InstrumentGlyph.Kind = InstrumentGlyph.Kind.HULL
@export var accent: Color = Color("85d8cc")
@export_range(0.0, 1.0) var low_warning_fraction: float = 0.2
var accessibility_compact: bool = false
var quiet: bool = false
var current_value: float = 0.0
var maximum_value: float = 100.0


func _ready() -> void:
	(%Caption as Label).text = caption
	var icon: InstrumentGlyph = %Glyph
	icon.kind = glyph
	icon.ink = accent
	icon.queue_redraw()
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(3)
	(%Bar as ProgressBar).add_theme_stylebox_override("fill", fill)
	set_reading(current_value, maximum_value)


func set_reading(current: float, maximum: float) -> void:
	current_value = current
	maximum_value = maximum
	if not is_node_ready():
		return
	var depleted: bool = current <= 0.0
	(%Value as Label).text = "%.1f / %.1f" % [current, maximum]
	(%Bar as ProgressBar).value = 100.0 * current / maximum if maximum > 0.0 else 0.0
	(%State as Label).text = "DEPLETED" if depleted else "AVAILABLE"
	(%LowWarning as Label).text = "! LOW / RETURN" if maximum > 0.0 and current / maximum <= low_warning_fraction else ""
	if accessibility_compact:
		(%Caption as Label).text = "%s / %.0f" % [caption.get_slice(" ", 0), maximum]
		(%Value as Label).text = "%.1f" % current
		(%State as Label).text = "DEPLETED" if depleted else ("! LOW / RETURN" if current / maximum <= low_warning_fraction else "AVAILABLE")
		(%LowWarning as Label).hide()
	else:
		(%Caption as Label).text = caption
		(%LowWarning as Label).show()
	if quiet:
		(%Caption as Label).text = caption.get_slice(" ",0)
		(%Value as Label).text = "%.0f" % current
		(%State as Label).visible = depleted or (maximum > 0.0 and current/maximum <= low_warning_fraction)
		(%LowWarning as Label).hide()
	(%State as Label).modulate = Color("ffb49e") if depleted else Color("a8c5cd")
