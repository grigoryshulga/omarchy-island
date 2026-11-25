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
  vec2 samplePoint=origin+(dotIndex*pitch+1.0)*pixel;
  float x=samplePoint.x/size.x;
  float u=mix(x,1.0-x,inputOnLeft);
  float centerY=origin.y+(grid.y*pitch-1.0)*pixel*0.5;
  float y=(samplePoint.y-centerY)/size.y;
  float rowStep=pitch*pixel/size.y;

  // The two edges diffuse through the filled interior on a fixed braille grid.
  float taper=smoothstep(0.0,0.10,u)*(1.0-smoothstep(0.90,1.0,u));
  float angle=12.5663706144*u-2.0*phase;
  float drift=sin(6.2831853072*u-phase+0.9);
  float upper=energy*(0.103+0.218*(0.5+0.5*sin(angle)));
  float lower=energy*(0.108+0.200*(0.5+0.5*sin(angle-0.69)));
  float voiceCenter=energy*(0.047*sin(angle-0.32)+0.023*drift);
  float workAngle=12.5663706144*u-phase;
  float workWidth=0.023+0.086*(0.5+0.5*sin(workAngle));
  float workCenter=0.019*sin(workAngle-0.55);
  float center=mix(voiceCenter,workCenter,morph)*taper;
  float upperWidth=0.5*rowStep+mix(upper,workWidth,morph)*taper;
  float lowerWidth=0.5*rowStep+mix(lower,workWidth,morph)*taper;
  float top=(center-upperWidth)*reveal;
  float bottom=(center+lowerWidth)*reveal;
  float definition=mix(smoothstep(0.0,0.28,energy),0.72,morph);
  float distance=min(abs(y-top),abs(y-bottom))/rowStep;
  float edge=1.0-smoothstep(0.12,1.39-0.46*definition,distance);
  float fill=0.28*smoothstep(top-0.028,top+0.023,y)*(1.0-smoothstep(bottom-0.023,bottom+0.028,y));
  float stroke=(0.43+0.52*definition)*edge;
  float background=0.075-0.027*smoothstep(0.0,0.5,abs(y));
  float alpha=min(1.0,reveal*2.0)*taper*max(background,fill+(1.0-fill)*stroke);
  float shine=0.12+(0.30+0.42*definition)*edge;
  vec3 color=mix(accent.rgb,highlight.rgb,shine);
  fragColor=vec4(color*alpha,alpha)*qt_Opacity;
}
