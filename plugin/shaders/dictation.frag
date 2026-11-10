#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  float amplitude;
  float morph;
  float phase;
  float column;
  vec4 accent;
};
void main() {
  vec2 p=qt_TexCoord0*size;
  // Two dots per time column, with the pitch locked to the whole field.
  vec2 pitch=vec2(size.x/2.0,3.0);
  vec2 cell=floor(p/pitch);
  vec2 center=(cell+0.5)*pitch;
  float y=abs(center.y-size.y*0.5);
  float voice=1.0-smoothstep(max(1.5,amplitude*size.y*0.47),max(1.5,amplitude*size.y*0.47)+1.5,y);
  float travel=0.5+0.5*sin(column*10.0-phase*4.0);
  float ridge=sin(column*6.283-phase*2.5)*size.y*0.17;
  float processing=exp(-pow((center.y-size.y*0.5-ridge)/3.0,2.0))*(0.3+0.7*travel);
  float ink=mix(voice,processing,morph);
  float radius=mix(0.42,1.12,ink);
  float dot=1.0-smoothstep(radius,radius+0.24,length(p-center));
  float edge=smoothstep(0.0,0.09,column+0.02)*smoothstep(0.0,0.09,1.02-column);
  float alpha=dot*(0.10+ink*0.85)*edge;
  fragColor=vec4(accent.rgb*alpha,alpha)*qt_Opacity;
}
