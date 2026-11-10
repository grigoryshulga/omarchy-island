#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  float phase;
  float solarHour;
};
uint mixBits(uint v) { v^=v>>16;v*=0x85ebca6bu;v^=v>>13;v*=0xc2b2ae35u;return v^(v>>16); }
float noise(uvec2 p,uint salt) { return float(mixBits(mixBits(p.x)^mixBits(p.y+0x9e3779b9u)^mixBits(salt))>>8)/16777216.0; }
void main() {
  vec2 uv=qt_TexCoord0;
  vec2 pixel=uv*size;
  uvec2 site=uvec2(floor(pixel/3.0));
  vec2 local=mod(pixel,3.0)-vec2(1.5);
  float hour=mod(solarHour,24.0);
  float daylight=smoothstep(-0.20,0.40,cos((hour-12.0)*0.2617994));
  float dawnDistance=abs(hour-6.0),duskDistance=abs(hour-18.0);
  float dawn=exp(-pow(min(dawnDistance,24.0-dawnDistance)/1.5,2.0));
  float dusk=exp(-pow(min(duskDistance,24.0-duskDistance)/1.7,2.0));
  vec3 zenith=mix(vec3(0.22,0.25,0.60),vec3(0.25,0.65,0.95),daylight);
  vec3 horizon=mix(vec3(0.44,0.32,0.65),vec3(0.62,0.82,0.98),daylight);
  zenith=mix(zenith,vec3(0.64,0.42,0.65),dawn*0.55);
  zenith=mix(zenith,vec3(0.48,0.31,0.65),dusk*0.75);
  horizon=mix(horizon,vec3(1.0,0.69,0.40),dawn);
  horizon=mix(horizon,vec3(1.0,0.42,0.28),dusk);
  vec3 color=mix(zenith,horizon,smoothstep(0.08,0.68,uv.y));

  // Fade inside every boundary, before the item or popup can clip any dots.
  // Both coverage and opacity dissolve, leaving no rectangular grid outline.
  vec2 edge=min(pixel,size-pixel);
  vec2 feather=max(vec2(1.0),min(size*0.24,vec2(80.0)));
  vec2 fade=smoothstep(vec2(0.0),feather,edge);
  float envelope=fade.x*fade.y;
  vec2 field=(uv-vec2(0.50,0.38))/vec2(0.60,0.62);
  envelope*=1.0-smoothstep(0.20,1.0,length(field));
  float core=envelope*(0.84+0.08*sin(uv.x*5.0+phase*0.12));
  float clock=phase*0.65+noise(site,71u);
  uint frame=uint(floor(clock));
  float coverage=0.10+0.58*core;
  float glyph=mix(step(1.0-coverage,noise(site,frame)),step(1.0-coverage,noise(site,frame+1u)),smoothstep(0.0,1.0,fract(clock)));
  float radius=mix(0.40,1.12,core);
  float dotMask=1.0-smoothstep(radius,radius+0.24,length(local));
  float alpha=dotMask*glyph*envelope*0.27;
  fragColor=vec4(color*alpha,alpha)*qt_Opacity;
}
