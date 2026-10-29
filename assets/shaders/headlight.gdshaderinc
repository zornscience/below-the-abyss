uniform vec2 lamp_origin = vec2(0.0);
uniform vec2 lamp_direction = vec2(1.0,0.0);
uniform float lamp_stops[9];
uniform float lamp_intensity = 0.0;
vec3 headlight(vec2 world) {
 vec2 offset = world-lamp_origin;
 float along = dot(offset,lamp_direction);
 if (lamp_intensity<=0.0 || along<0.0 || along>600.0) return vec3(0.0);
 float side = dot(offset,vec2(-lamp_direction.y,lamp_direction.x));
 float slope = side/max(along,1.0);
 float cone = 1.0-smoothstep(0.12,0.22,abs(slope));
 float ray = clamp((slope+0.22)/0.44*8.0,0.0,8.0);
 int index = min(int(floor(ray)),7);
 // Conservative neighbouring rays keep the beam from leaking through rock.
 float stop = min(lamp_stops[index],lamp_stops[index+1]);
 float surface = 1.0-smoothstep(stop+3.0,stop+22.0,length(offset));
 float falloff = pow(1.0-clamp(along/600.0,0.0,1.0),1.3);
 return vec3(0.72,0.82,0.63)*cone*surface*falloff*lamp_intensity;
}
