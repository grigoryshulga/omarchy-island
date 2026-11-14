#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  float amount;
  vec4 accent;
  vec4 trackColor;
  float trackOpacity;
  float phase;
  float charging;
};
void main() {
  vec2 p=qt_TexCoord0*size;
  float pitch=3.0;
  vec2 local=mod(p,pitch)-vec2(pitch*0.5);
  float filled=step((floor(p.x/pitch)+0.5)*pitch,size.x*amount);
  float radius=mix(0.60,1.26,amount);
  // A smooth wave travels through the dots without changing the charge boundary.
  float wave=0.5+0.5*cos(6.2831853*(p.x/max(size.x,1.0)-phase));
  wave=wave*wave*charging;
  radius*=mix(1.0,1.22,wave);
  float dots=1.0-smoothstep(radius,radius+0.22,length(local));
  float foregroundAlpha=dots*filled*mix(0.95,mix(0.72,1.0,wave),charging);
  // The whole track remains legible even at zero; filled ink sits above it.
  float trackDots=1.0-smoothstep(0.72,0.94,length(local));
  float backgroundAlpha=trackDots*clamp(trackOpacity,0.0,1.0);
  float alpha=foregroundAlpha+backgroundAlpha*(1.0-foregroundAlpha);
  vec3 color=accent.rgb*foregroundAlpha+trackColor.rgb*backgroundAlpha*(1.0-foregroundAlpha);
  fragColor=vec4(color,alpha)*qt_Opacity;
}
