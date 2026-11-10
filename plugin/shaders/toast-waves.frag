#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  vec2 origin;
  float phase;
  float spacing;
  float bandWidth;
  float speed;
  float cornerRadius;
  vec4 accent;
};
uint mixBits(uint v) {
  v ^= v >> 16; v *= 0x85ebca6bu;
  v ^= v >> 13; v *= 0xc2b2ae35u;
  return v ^ (v >> 16);
}
float noise(uvec2 site,uint frame) {
  return float(mixBits(mixBits(site.x)^mixBits(site.y+0x9e3779b9u)^mixBits(frame))>>8)/16777216.0;
}
void main() {
  vec2 pixel=qt_TexCoord0*size;
  vec2 center=origin;
  // Pixel-space circular fronts travel from the left edge to the right.
  float distanceFromOrigin=length(pixel-center);
  float band=mod(distanceFromOrigin-phase*speed,spacing)-spacing*0.5;
  float wave=exp(-pow(band/bandWidth,2.0));
  float edgeFade=smoothstep(0.0,0.20,1.0-qt_TexCoord0.x);
  float strength=wave*edgeFade*mix(1.0,0.35,qt_TexCoord0.x);
  uvec2 site=uvec2(floor(pixel/3.0));
  vec2 local=mod(pixel,3.0)-vec2(1.5);
  float clock=phase*0.65+noise(site,31u);
  uint frame=uint(floor(clock));
  float coverage=mix(0.28,0.85,wave);
  float pattern=mix(step(1.0-coverage,noise(site,frame)),step(1.0-coverage,noise(site,frame+1u)),smoothstep(0.0,1.0,fract(clock)));
  float radius=mix(0.50,1.12,wave);
  float dots=(1.0-smoothstep(radius,radius+0.25,length(local)))*pattern;
  vec2 box=abs(pixel-size*0.5)-(size*0.5-vec2(cornerRadius));
  float edge=length(max(box,vec2(0.0)))+min(max(box.x,box.y),0.0)-cornerRadius;
  float alpha=dots*strength*0.23*(1.0-smoothstep(-0.5,0.5,edge));
  fragColor=vec4(accent.rgb*alpha,alpha)*qt_Opacity;
}
