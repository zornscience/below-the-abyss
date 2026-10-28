shader_type canvas_item;
render_mode unshaded;
uniform vec4 cell = vec4(0.0,0.0,1.0,1.0);
uniform bool atlas_input = true;
uniform int mode = 0;
uniform float phase = 0.0;
uniform float amount = 1.0;
varying float individual_phase;
void vertex() { individual_phase = INSTANCE_CUSTOM.x*6.283185; }
void fragment() {
 vec2 p = atlas_input ? (UV-cell.xy)/cell.zw : UV;
 float clock = phase+individual_phase;
 float tail = 1.0-smoothstep(0.22,0.72,p.x);
 float wave = sin(clock-p.x*9.0)*tail*0.025;
 if (mode==1) wave = sin(clock-p.x*12.0)*(1.0-smoothstep(0.55,0.92,p.x))*0.06;
 if (mode==2) wave = sin(clock)*smoothstep(0.45,0.8,p.y)*sin(clamp(p.x,0.0,1.0)*3.14159)*0.035;
 if (mode==3) wave *= 1.0-smoothstep(0.25,0.48,p.x);
 p.y += wave*amount;
 vec4 texel = texture(TEXTURE,cell.xy+clamp(p,vec2(0.001),vec2(0.999))*cell.zw);
 if (p.y<0.0 || p.y>1.0) texel.a = 0.0;
 COLOR = texel*COLOR;
}
