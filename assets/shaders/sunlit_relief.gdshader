shader_type canvas_item;
render_mode unshaded;
// Soft ends on distant illustration layers; no screen read or animated noise.
void fragment() {
 vec4 paint = texture(TEXTURE,UV) * COLOR;
 float vertical = smoothstep(0.0,0.12,UV.y) * (1.0-smoothstep(0.88,1.0,UV.y));
 float horizontal = smoothstep(0.0,0.08,UV.x) * (1.0-smoothstep(0.82,1.0,UV.x));
 COLOR = vec4(paint.rgb,paint.a*vertical*horizontal);
}
