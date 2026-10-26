shader_type canvas_item;
varying vec2 rock_position;
void vertex() { rock_position = VERTEX; }
void fragment() {
 float strata = (fract(rock_position.y * 0.025 + floor(rock_position.x * 0.009) * 0.03) * 2.0 - 1.0);
 float grain = fract(dot(floor(rock_position / 3.0), vec2(0.618,0.381)));
 vec3 stone = mix(vec3(0.035,0.095,0.12), COLOR.rgb * vec3(0.32,0.43,0.46), 0.55);
 COLOR = vec4(stone * (0.85 + 0.12 * strata + 0.08 * grain), COLOR.a);
}
