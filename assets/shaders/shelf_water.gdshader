shader_type canvas_item;
varying float authored_y;
void vertex() { authored_y = VERTEX.y; }
void fragment() {
 float depth = clamp(authored_y / 1800.0, 0.0, 1.0);
 vec3 shallow = vec3(0.025, 0.125, 0.17);
 vec3 deep = vec3(0.006, 0.019, 0.045);
 COLOR = vec4(mix(shallow, deep, smoothstep(0.0, 1.0, depth)), 1.0);
}
