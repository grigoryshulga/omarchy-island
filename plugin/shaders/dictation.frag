#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  float cellSize;
  float morph;
  float phase;
  float still;
  mat4 samplesA;
  mat4 samplesB;
  mat4 samplesC;
  vec4 accent;
  vec4 highlight;
};

float sampleAt(int index) {
  int col=(index%16)/4, row=index%4;
  if(index<16) return samplesA[col][row];
  if(index<32) return samplesB[col][row];
  return samplesC[col][row];
}

float gaussian(float distance, float width) {
  float t=distance/width;
  return exp(-t*t);
}

void main() {
  if (min(size.x,size.y)<cellSize) {fragColor=vec4(0.0);return;}
  vec2 p=qt_TexCoord0*size;
  vec2 grid=floor(size/cellSize);
  vec2 origin=(size-grid*cellSize)*0.5;
  vec2 coord=(p-origin)/cellSize;
  vec2 group=floor(coord);
  if(any(lessThan(group,vec2(0.0))) || any(greaterThanEqual(group,grid))) {fragColor=vec4(0.0);return;}
  // Align the dots as two columns by four rows, with extra space between pairs.
  vec2 local=fract(coord);
  vec2 dotCenter=vec2(local.x<0.5 ? 0.36 : 0.64,0.17+floor(local.y*4.0)*0.22);
  vec2 center=origin+(group+dotCenter)*cellSize;
  float u=center.x/size.x;
  float y=center.y/size.y-0.5;
  float taper=pow(sin(3.14159*u),0.74);

  float position=u*47.0;
  int slot=int(position);
  float sampleLevel=mix(sampleAt(slot),sampleAt(min(slot+1,47)),smoothstep(0.0,1.0,fract(position)));
  float energy=mix(min(1.0,sqrt(max(sampleLevel,0.0))*1.6),0.40,still);
  float current=u*11.2-phase*3.0;
  float crossflow=u*19.0+phase*2.0;
  float swell=0.5+0.5*sin(u*6.8-phase*2.0);
  float spine=taper*(sin(current)*(0.09+0.13*energy)+sin(crossflow)*0.035);
  float span=taper*(0.095+0.23*energy)*(0.65+0.35*swell);
  float body=gaussian(y-spine,0.06+span*0.62);
  float crest=gaussian(y-spine-span*(0.48+0.18*cos(crossflow)),0.065);
  float reflection=gaussian(y-spine+span*0.82,0.055);
  float recording=clamp(0.55*body+0.74*crest+0.38*reflection,0.0,1.0);
  float glint=0.5+0.5*sin(u*19.0-phase*5.0);
  float workSpine=sin(u*12.0-phase*4.0)*0.20*taper;
  float working=gaussian(y-workSpine,0.084)*(0.55+0.45*glint)
    +0.24*gaussian(y+workSpine*0.55,0.06);
  float ink=clamp(mix(recording,working,morph),0.0,1.0);
  float radius=cellSize*mix(0.039,0.102,ink);
  float distance=length(p-center);
  float dot=1.0-smoothstep(radius-0.18,radius+0.35,distance);
  float halo=(1.0-smoothstep(radius,radius+0.64,distance))*ink*0.12;
  float alpha=(dot*(0.11+0.83*ink)+halo)*taper;
  vec3 color=mix(accent.rgb,highlight.rgb,0.72*ink*(0.55+0.45*glint));
  fragColor=vec4(color*alpha,alpha)*qt_Opacity;
}
