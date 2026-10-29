shader_type canvas_item;
render_mode unshaded;
varying float world_y;
void vertex() { world_y = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).y; }
void fragment() {
 vec4 paint = texture(TEXTURE,UV)*COLOR;
 COLOR = vec4(paint.rgb,paint.a*smoothstep(0.0,20.0,world_y)*(1.0-smoothstep(1200.0,2000.0,world_y)));
}
