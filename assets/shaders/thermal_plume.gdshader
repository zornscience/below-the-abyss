shader_type canvas_item;
render_mode unshaded;
uniform float phase = 0.0;
uniform bool calm = false;
void fragment() {
 // Local sprite only. Explicit simulation phase freezes with pause/Reduced Motion.
 vec2 p = UV;
 float edge = smoothstep(0.0,0.16,p.y)*(1.0-smoothstep(0.84,1.0,p.y));
 float billow = 0.65+0.35*sin(p.x*27.0-phase*2.5+sin(p.y*21.0+phase)*1.7);
 float grain = 0.78+0.22*sin(p.x*76.0+p.y*43.0-phase*3.0);
 float density = calm ? 0.65 : billow*grain;
 vec4 art = texture(TEXTURE,UV);
 COLOR *= vec4(art.rgb,art.a*edge*density);
}
