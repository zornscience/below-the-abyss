shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/headlight.gdshaderinc"
varying vec2 edge_world;
void vertex() { edge_world = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
 vec4 paint = texture(TEXTURE,UV)*COLOR;
 COLOR = vec4(paint.rgb+headlight(edge_world),paint.a);
}
