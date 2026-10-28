shader_type canvas_item;
render_mode unshaded;
// Texture-local, subpixel surface movement. No screen read or engine TIME.
uniform float phase = 0.0;
uniform float motion_amount = 1.0;
void fragment() {
 vec2 uv = UV;
 float surface = exp(-pow((uv.y - 0.235) * 32.0, 2.0));
 uv.x += sin(uv.y * 90.0 + phase * 0.28) * 0.00045 * surface * motion_amount;
 COLOR = texture(TEXTURE, uv) * COLOR;
}
