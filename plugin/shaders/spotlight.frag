#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  vec2 center;
  float phase;
  float spotRadius;
  float cornerRadius;
  vec4 accent;
  float profile;
  float hoverOpacity;
  vec2 rippleCenter;
  float rippleProgress;
};
uint mixBits(uint v) {
  v ^= v >> 16; v *= 0x85ebca6bu;
  v ^= v >> 13; v *= 0xc2b2ae35u;
  return v ^ (v >> 16);
}
float noise(uvec2 position, uint frame) {
  return float(mixBits(mixBits(position.x ^ 0x9e3779b9u) ^ mixBits(position.y ^ 0x68bc21ebu) ^ mixBits(frame ^ 0x02e5be93u)) >> 8) / 16777216.0;
}
float dots(vec2 local,float core,float a,float b,float blend) {
  // The pitch never changes: profile affects radius and how many fixed sites
  // are lit, not the coordinates of the lattice or its spacing.
  float radius=mix(1.08,mix(0.45,1.25,core),profile);
  float softness=mix(0.32,0.22,profile);
  float coverage=mix(0.60,mix(0.18,0.90,core),profile);
  float pattern=mix(step(1.0-coverage,a),step(1.0-coverage,b),blend);
  return (1.0-smoothstep(radius,radius+softness,length(local)))*pattern;
}
void main() {
  vec2 pixel=qt_TexCoord0*size;
  vec2 delta=pixel-center;
  float angle=atan(delta.y,delta.x);
  float edge=1.0+0.045*sin(angle*3.0+phase*0.8)+0.025*sin(angle*7.0-phase*0.6)+0.012*sin(angle*11.0+phase*0.3);
  float normalized=length(delta)/(spotRadius*edge);
  float falloff=1.0-smoothstep(0.20,1.0,normalized);
  float core=1.0-smoothstep(0.0,0.95,normalized);
  vec2 local=mod(pixel,3.0)-vec2(1.5);
  uvec2 site=uvec2(floor(pixel/3.0));
  float clock=phase*1.8+noise(site,17u);
  uint frame=uint(floor(clock));
  float a=noise(site,frame), b=noise(site,frame+1u);
  float blend=smoothstep(0.0,1.0,fract(clock));
  float alpha=dots(local,core,a,b,blend)*falloff*hoverOpacity*0.18;

  float reach=max(1.0,length(max(rippleCenter,size-rippleCenter)));
  float distanceFromClick=length(pixel-rippleCenter);
  float travel=1.0-pow(1.0-rippleProgress,3.0);
  float waveRadius=reach*travel;
  float band=(distanceFromClick-waveRadius)/max(4.0,spotRadius*0.08);
  float waveFade=1.0-smoothstep(0.05,1.0,rippleProgress);
  float ring=exp(-band*band)*waveFade;
  float waveCore=1.0-smoothstep(0.0,1.0,distanceFromClick/reach);
  alpha+=dots(local,waveCore,a,b,blend)*ring*0.38;

  vec2 box=abs(pixel-size*0.5)-(size*0.5-vec2(cornerRadius));
  float distanceToEdge=length(max(box,vec2(0.0)))+min(max(box.x,box.y),0.0)-cornerRadius;
  alpha=clamp(alpha,0.0,1.0)*(1.0-smoothstep(-0.5,0.5,distanceToEdge));
  fragColor=vec4(accent.rgb*alpha,alpha)*qt_Opacity;
}
