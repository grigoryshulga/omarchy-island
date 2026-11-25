#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  vec2 grid;
  float pixel;
  float morph;
  float phase;
  float energy;
  float inputOnLeft;
  float reveal;
  vec4 accent;
  vec4 highlight;
};

void main() {
  const float pitch=3.0;
  vec2 origin=floor((size-(grid*pitch-1.0)*pixel)*0.5);
  vec2 coord=(qt_TexCoord0*size-origin)/pixel;
  vec2 dotIndex=floor(coord/pitch);
  vec2 local=coord-dotIndex*pitch;
  // Leave one blank pixel between squares in both directions.
  if(reveal<=0.0 || any(lessThan(dotIndex,vec2(0.0))) || any(greaterThanEqual(dotIndex,grid))
     || any(greaterThanEqual(local,vec2(2.0)))) {
    fragColor=vec4(0.0);
    return;
  }
  vec2 samplePoint=(origin+(dotIndex*pitch+1.0)*pixel)/size;
  float u=mix(samplePoint.x,1.0-samplePoint.x,inputOnLeft);
  float y=samplePoint.y-0.5;

  // The two edges diffuse through the filled interior on a fixed braille grid.
  float taper=smoothstep(0.0,0.10,u)*(1.0-smoothstep(0.90,1.0,u));
  float crest=0.5+0.5*sin(12.5663706144*u-2.0*phase);
  float undertow=0.5+0.5*sin(9.1*u+phase+1.1);
  float progress=0.5+0.5*sin(14.0*u-phase);
  float center=0.042*sin(11.0*u-2.0*phase)+0.045*energy*(2.0*undertow-1.0);
  float width=0.054+energy*(0.10+0.244*(0.72*crest+0.28*undertow));
  center=mix(center,0.026*sin(11.0*u-phase),morph)*taper;
  width=mix(width,0.058+0.084*progress,morph)*taper;
  float top=(center-width*(0.91+0.09*undertow))*reveal;
  float bottom=(center+width*(0.87+0.13*crest))*reveal;
  float edge=1.0-smoothstep(0.015,0.088,min(abs(y-top),abs(y-bottom)));
  float fill=smoothstep(top-0.032,top+0.019,y)*(1.0-smoothstep(bottom-0.024,bottom+0.024,y));
  float background=0.075-0.027*smoothstep(0.0,0.5,abs(y));
  float alpha=min(1.0,reveal*2.0)*taper*max(background,fill*(0.32+0.66*edge));
  float shine=0.20+0.52*edge;
  vec3 color=mix(accent.rgb,highlight.rgb,shine);
  fragColor=vec4(color*alpha,alpha)*qt_Opacity;
}
