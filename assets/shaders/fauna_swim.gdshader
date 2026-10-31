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
 // Posterior undulation, not whole-image rocking. The head remains a stable anchor.
 float tail = 1.0-smoothstep(0.16,0.65,p.x);
 float wave = sin(clock-p.x*9.0)*tail*0.045;
 if (mode==1) { // Eel: a travelling body wave tapering into a still head.
  wave = sin(clock-p.x*13.0)*pow(1.0-smoothstep(0.20,0.85,p.x),1.1)*0.075;
 }
 if (mode==2) { // Turtle: alternating flipper strokes around a stable shell.
  float flipper = smoothstep(0.10,0.28,abs(p.y-0.5))*(1.0-smoothstep(0.68,0.82,p.x))*smoothstep(0.12,0.30,p.x);
  wave = sin(clock+(p.y>0.5 ? 0.55 : 0.0))*flipper*0.065;
  p.x += cos(clock)*flipper*0.018*amount;
 }
 if (mode==3) { // Hammerhead: powerful caudal stroke; no bending of the head.
  wave = sin(clock-p.x*8.0)*pow(tail,1.6)*0.055;
 }
 if (mode==4) { // Squid: mantle contraction and trailing-arm waves.
  float arms = 1.0-smoothstep(0.25,0.60,p.x);
  wave = sin(clock*1.7-p.x*10.0)*arms*0.055;
  p.y += (p.y-0.5)*sin(clock*1.7)*0.04*(1.0-arms)*amount;
 }
 if (mode==5) { // Jelly: slow bell pulses, fine trailing filaments.
  float skirt = 1.0-smoothstep(0.2,0.65,p.x);
  wave = sin(clock-p.x*9.0)*skirt*0.035;
  p.y += (p.y-0.5)*sin(clock)*0.07*amount;
 }
 p.y += wave*amount;
 vec4 texel = texture(TEXTURE,cell.xy+clamp(p,vec2(0.001),vec2(0.999))*cell.zw);
 if (p.y<0.0 || p.y>1.0) texel.a = 0.0;
 COLOR = texel*COLOR;
}
