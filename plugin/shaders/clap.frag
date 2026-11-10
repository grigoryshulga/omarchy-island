#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  float motionPhase;
  vec4 accent;
};
layout(binding = 1) uniform sampler2D source;
void main() {
  vec2 pixel=qt_TexCoord0*size;
  vec2 site=floor(pixel/3.0), local=mod(pixel,3.0)-vec2(1.5);
  // Sample one original GIF frame at each fixed grid site, then draw a dot.
  // The shared frame bounds preserve hand travel and the clap's impact rays.
  float aspect=256.0/224.0;
  vec2 extent=vec2(min(size.x,size.y*aspect),min(size.y,size.x/aspect));
  vec2 uv=(site*3.0+vec2(1.5)-size*0.5)/max(extent,vec2(1.0))+0.5;
  float inside=step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
  float frame=min(floor(fract(motionPhase)*8.0),7.0);
  vec2 atlasUv=vec2((frame+clamp(uv.x,0.002,0.998))/8.0,clamp(uv.y,0.002,0.998));
  float mask=texture(source,atlasUv).r*inside;
  float dotMask=1.0-smoothstep(0.80,1.12,length(local));
  float alpha=dotMask*smoothstep(0.08,0.65,mask)*0.90*accent.a;
  fragColor=vec4(accent.rgb*alpha,alpha)*qt_Opacity;
}
