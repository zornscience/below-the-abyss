shader_type canvas_item;
varying vec2 world;
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	float a=fract(sin(dot(i,vec2(127.1,311.7)))*43758.5453);
	float b=fract(sin(dot(i+vec2(1,0),vec2(127.1,311.7)))*43758.5453);
	float c=fract(sin(dot(i+vec2(0,1),vec2(127.1,311.7)))*43758.5453);
	float d=fract(sin(dot(i+vec2(1,1),vec2(127.1,311.7)))*43758.5453);
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
	float n=noise(world*0.008)*0.6+noise(world*0.035)*0.3+noise(world*0.14)*0.1;
	float layers=sin(world.y*0.05+noise(world*0.012)*5.0)*0.08;
	vec3 mineral=mix(vec3(0.02,0.055,0.09),vec3(0.12,0.24,0.22),n);
	COLOR.rgb=COLOR.rgb*(0.75+n*0.9+layers)+mineral*0.25;
}
