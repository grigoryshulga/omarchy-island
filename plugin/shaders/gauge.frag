#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  float amount;
  vec4 accent;
};
void main() {
  vec2 p=qt_TexCoord0*size;
  float pitch=3.0;
  vec2 local=mod(p,pitch)-vec2(pitch*0.5);
  float filled=step((floor(p.x/pitch)+0.5)*pitch,size.x*amount);
  float radius=mix(0.40,mix(0.60,1.26,amount),filled);
  float dots=1.0-smoothstep(radius,radius+0.22,length(local));
  float alpha=dots*mix(0.14,0.95,filled);
  fragColor=vec4(accent.rgb*alpha,alpha)*qt_Opacity;
}
