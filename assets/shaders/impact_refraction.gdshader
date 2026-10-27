shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float phase = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float ring = exp(-pow((d-phase)/0.1,2.0))*(1.0-phase);
	vec2 bend = normalize(p+vec2(0.0001))*ring*0.008;
	vec3 water = texture(screen_texture,SCREEN_UV-bend).rgb;
	COLOR = vec4(water,ring*0.85);
}
