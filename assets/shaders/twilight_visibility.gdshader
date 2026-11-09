shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform mat4 screen_to_world;
uniform vec2 view_size;
uniform vec2 vessel;
uniform vec2 facing;
uniform float ambient = 0.065;
uniform float passive_radius = 95.0;
uniform float safety_radius = 150.0;
uniform float light_range = 480.0;
uniform float cone_angle = 0.24;
uniform float light_stops[9];
uniform float echo_gain = 0.8;
uniform float duration = 6.0;
uniform bool outline = false;
uniform bool reduced = false;
uniform vec4 pings[8];
uniform float speeds[8];
varying vec2 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
 vec2 world = outline ? (screen_to_world * vec4(world_point,0.0,1.0)).xy : (screen_to_world * vec4(SCREEN_UV*view_size,0.0,1.0)).xy;
 vec2 offset = world-vessel;
 float d = length(offset);
 float close = 1.0-smoothstep(passive_radius,safety_radius,d);
 float cone = smoothstep(cos(cone_angle),cos(cone_angle*0.65),dot(normalize(offset+vec2(0.0001)),facing));
 float forward = dot(offset,facing);
 float side = facing.x*offset.y-facing.y*offset.x;
 int ray = clamp(int((side/max(forward,0.001)/0.22*0.5+0.5)*8.0),0,8);
 float stop = light_stops[ray]>0.0 ? min(light_range,light_stops[ray]+20.0) : light_range;
 float light = cone*(1.0-smoothstep(stop*0.65,stop,d));
 float echo = 0.0;
 for(int i=0;i<8;i++) {
  if(speeds[i]>0.0) {
   float dist = distance(world,pings[i].xy);
   float since = pings[i].z-dist/speeds[i];
   if(dist<=pings[i].w && since>=0.0) echo=max(echo,clamp(1.0-since/duration,0.0,1.0));
  }
 }
 if(outline) COLOR=vec4(reduced ? vec3(0.80,0.88,0.88) : vec3(0.38,0.66,0.65),max(close*0.48,echo*0.72));
 else COLOR=vec4(texture(screen_tex,SCREEN_UV).rgb*max(ambient,max(close,max(light,echo*echo_gain))),1.0);
}
