class_name UiTypography
extends RefCounted
## Semantic text metrics, shared by Controls and custom-drawn instruments.
const SCALE: Dictionary = {"compact":0.9,"standard":1.0,"large":1.25}
const BASE: Dictionary = {&"body":16,&"dialog_button":16,&"menu_button":17,&"heading":20,
	&"section":18,&"hud":16,&"secondary":14,&"measurement":18,&"title":56}
const BUTTON_HEIGHT: Dictionary = {"compact":32,"standard":34,"large":42}


static func base(role: StringName) -> int:
	return int(BASE.get(role,BASE[&"body"]))


static func size_for(role: StringName,scale_name: String = "standard",width: float = 1280.0) -> int:
	var pixels: int = base(role)
	if role==&"title": pixels = 40 if width<1100 else (64 if width>=1700 else 56)
	return maxi(14,roundi(pixels*float(SCALE.get(scale_name,1.0))))


static func for_control(control: Control,role: StringName) -> int:
	return size_for(role,String(control.get_meta("typography_scale","standard")),control.get_viewport_rect().size.x)


static func role_for(control: Control) -> StringName:
	return StringName(control.get_meta("typography_role",&"dialog_button" if control is BaseButton else &"body"))


static func style(control: Control,role: StringName) -> void:
	control.set_meta("typography_role",role)
	apply(control,"standard")


static func apply(control: Control,scale_name: String) -> void:
	if not control is Label and not control is BaseButton: return
	var role: StringName = role_for(control)
	var width: float = control.get_viewport_rect().size.x if control.is_inside_tree() else 1280.0
	var pixels: int = size_for(role,scale_name,width)
	control.add_theme_font_size_override("font_size",pixels)
	if control is OptionButton: (control as OptionButton).get_popup().add_theme_font_size_override("font_size",pixels)
	if control is Button:
		var button: Button = control as Button
		button.custom_minimum_size.y = int(BUTTON_HEIGHT.get(scale_name,34))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var parent: Node = button.get_parent()
		if parent is HFlowContainer or parent is HBoxContainer:
			var text_width: float = button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+24
			button.custom_minimum_size.x = clampf(text_width,36 if button.text.length()<=2 else 64,280)
			if parent is HBoxContainer: button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
