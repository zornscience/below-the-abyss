shader_type canvas_item;
render_mode unshaded;
// Feather the rectangular ends of a painted relief layer, not its rock silhouette.
void fragment() {
 vec4 paint = texture(TEXTURE, UV);
 float fade = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.88, 1.0, UV.y));
 COLOR = paint * COLOR;
 COLOR.a *= fade;
}
