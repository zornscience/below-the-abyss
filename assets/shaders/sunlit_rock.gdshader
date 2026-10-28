shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/headlight.gdshaderinc"
uniform sampler2D painted_rock : source_color, repeat_enable, filter_linear_mipmap;
uniform vec3 mineral_tint : source_color = vec3(1.0);
varying vec2 rock_world;
varying float opacity;
void vertex() {
 rock_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
 opacity = COLOR.a;
}
void fragment() {
 // One cached illustrated material sample replaces the legacy octave-noise pass.
 vec3 paint = texture(painted_rock, rock_world / 768.0).rgb;
 float depth = clamp(rock_world.y / 1200.0, 0.0, 1.0);
 COLOR = vec4(paint * mineral_tint * mix(vec3(0.46,0.63,0.66),vec3(0.27,0.40,0.44),depth)+headlight(rock_world),opacity);
}
