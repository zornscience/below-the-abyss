class_name TutorialCard
extends PanelContainer
var title_label: Label
var body_label: Label
func _ready() -> void:
	theme = preload("res://resources/balance/instrument_theme.tres")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(24,112)
	custom_minimum_size = Vector2(350,0)
	size = Vector2(420,0)
	var content: VBoxContainer = VBoxContainer.new()
	add_child(content)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size",18)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title_label)
	body_label = Label.new()
	body_label.add_theme_font_size_override("font_size",16)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(body_label)
	hide()
func display(title: String,body: String) -> void:
	title_label.text = title
	body_label.text = body
	visible = not title.is_empty()
