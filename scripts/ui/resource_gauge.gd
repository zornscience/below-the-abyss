class_name ResourceGauge
extends PanelContainer
## Read-only presentation. Values and maxima are supplied by domain components.

@export var caption: String = "HULL INTEGRITY"
@export var glyph: InstrumentGlyph.Kind = InstrumentGlyph.Kind.HULL
@export var accent: Color = Color("85d8cc")
@export_range(0.0, 1.0) var low_warning_fraction: float = 0.2
var accessibility_compact: bool = false
var quiet: bool = false
var fraction: float = 0.0
var reading_color: Color = Color("ef4444")
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
	var valid: bool = is_finite(current) and is_finite(maximum) and maximum > 0.0
	fraction = clampf(current / maximum,0.0,1.0) if valid else 0.0
	var depleted: bool = not valid or current <= 0.0
	(%Value as Label).text = "%.1f / %.1f" % [current, maximum]
	(%Bar as ProgressBar).value = 100.0 * fraction
	(%State as Label).text = "DEPLETED" if depleted else "AVAILABLE"
	(%LowWarning as Label).text = "! LOW / RETURN" if maximum > 0.0 and fraction <= low_warning_fraction else ""
	if accessibility_compact:
		(%Caption as Label).text = "%s / %.0f" % [caption.get_slice(" ", 0), maximum]
		(%Value as Label).text = "%.1f" % current
		(%State as Label).text = "DEPLETED" if depleted else ("! LOW / RETURN" if fraction <= low_warning_fraction else "AVAILABLE")
		(%LowWarning as Label).hide()
	else:
		(%Caption as Label).text = caption
		(%LowWarning as Label).show()
	if quiet:
		(%Caption as Label).text = "POWER" if glyph==InstrumentGlyph.Kind.BATTERY else caption.get_slice(" ",0)
		(%Value as Label).text = "%d%%" % roundi(fraction*100.0)
		(%State as Label).text = "! INVALID" if not valid else ("! EMPTY" if depleted else ("! LOW" if fraction<=1.0/3.0 else ""))
		(%State as Label).visible = not (%State as Label).text.is_empty()
		(%Bar as Control).hide()
		(%LowWarning as Control).hide()
		reading_color = Color("22c55e") if fraction>=2.0/3.0 else (Color("eab308") if fraction>1.0/3.0 else Color("ef4444"))
		(%Value as Label).add_theme_color_override("font_color",reading_color)
		(%Glyph as InstrumentGlyph).ink = reading_color
		(%Glyph as InstrumentGlyph).queue_redraw()

	(%State as Label).modulate = Color("ffb49e") if depleted else Color("a8c5cd")

func make_compact() -> void:
	quiet = true
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	add_child(row)
	for node: Control in [%Glyph,%Caption,%Value,%State]:
		node.reparent(row)
		if node is Label:
			node.set_meta("typography_role",&"hud")
			UiTypography.style(node,&"hud")
	(%Caption as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	($Content as Control).hide()
	var style: StyleBoxEmpty = StyleBoxEmpty.new()
	add_theme_stylebox_override("panel",style)
	set_meta("a11y_style",[true,style])
	set_reading(current_value,maximum_value)
