shader_type canvas_item;
uniform sampler2D rock_paint : source_color, repeat_enable, filter_linear_mipmap;
varying vec2 rock_position;
void vertex() { rock_position = VERTEX; }
void fragment() {
 vec3 paint = texture(rock_paint, rock_position / 384.0).rgb;
 COLOR = vec4(paint * vec3(0.62, 0.72, 0.76), COLOR.a);
}
