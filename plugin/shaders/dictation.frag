#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  vec2 grid;
  float pitch;
  float morph;
  float phase;
  float inputOnLeft;
  float reveal;
  float sampleOffset;
  float still;
  mat4 samplesA;
  mat4 samplesB;
  vec4 accent;
  vec4 highlight;
};

float sampleAt(int index) {
  int column=(index%16)/4, row=index%4;
  return index<16 ? samplesA[column][row] : samplesB[column][row];
}

void main() {
  vec2 origin=(size-grid*pitch)*0.5;
  vec2 coord=(qt_TexCoord0*size-origin)/pitch;
  vec2 cell=floor(coord);
  if(any(lessThan(cell,vec2(0.0))) || any(greaterThanEqual(cell,grid))) {
    fragColor=vec4(0.0);
    return;
  }
  vec2 center=(origin+(cell+0.5)*pitch)/size;
  float u=mix(center.x,1.0-center.x,inputOnLeft);
  float front=1.10-1.18*reveal;
  float visibility=smoothstep(front-0.05,front+0.04,u);
  if(visibility<=0.0) {fragColor=vec4(0.0);return;}
  float bead=1.0-smoothstep(0.012,0.074,abs(u-front));
  float distance=max(abs(fract(coord.x)-0.5),abs(fract(coord.y)-0.5));
  float tile=1.0-smoothstep(0.23,0.40,distance);

  // The field is sampled at fixed pixel centers. Only the liquid underneath
  // moves. Dictation.js evaluates the same field on Qt Quick's software backend.
  float peak=0.0;
  if(still<0.5 && morph<1.0) {
    float position=max(0.0,min(31.0,u*31.0/0.84)-sampleOffset);
    int slot=int(position);
    peak=mix(sampleAt(slot),sampleAt(min(slot+1,31)),fract(position));
  }
  float taper=smoothstep(0.0,0.16,u)*(1.0-smoothstep(0.86,1.0,u));
  float pressure=pow(smoothstep(0.015,0.9,peak),0.55)*taper;
  float ripple=sin(10.0*u+phase);
  float eddy=sin(21.0*u+2.0*phase);
  float pulse=pow(0.5+0.5*sin(16.0*u+2.0*phase),2.0);
  float voiceCenter=pressure*(0.095*ripple+0.044*eddy-0.012);
  float workCenter=0.058*ripple*taper;
  float thickness=mix(0.034+0.228*pressure,0.042+0.17*pulse*taper,morph);
  thickness+=0.14*bead*taper;
  float depth=center.y-0.5-mix(voiceCenter,workCenter,morph);
  float body=1.0-smoothstep(thickness-0.044,thickness+0.044,abs(depth));
  // Processing curls into twin strands. Loud crests instead shed little drops.
  float split=morph*taper*smoothstep(0.25,0.76,pulse);
  float channel=split*(1.0-smoothstep(0.017,0.076,abs(depth)));
  float wake=0.5+0.5*sin(57.0*u+4.0*phase);
  float droplets=(1.0-morph)*smoothstep(0.32,0.84,pressure)*smoothstep(0.58,0.95,wake);
  float dropletDistance=abs(depth+thickness+0.066+0.058*wake);
  float droplet=droplets*(1.0-smoothstep(0.012,0.057,dropletDistance));
  float ink=max(body*(1.0-0.91*channel),0.83*droplet);
  float sheen=max(0.42+mix(0.32*pressure,0.22*pulse,morph),0.84*bead);
  float intensity=mix(pressure,0.44+0.56*pulse,morph);
  float surface=sheen*(1.0-smoothstep(0.014,0.093,abs(depth+thickness*0.52)));
  float reflection=0.42*intensity*(1.0-smoothstep(0.014,0.054,abs(depth-thickness*0.64)));
  float shine=max(surface,reflection);
  float opacity=visibility*taper*max(0.58+0.42*intensity,0.88*bead);
  float alpha=tile*ink*opacity*(0.52+0.48*shine);
  vec3 color=mix(accent.rgb,highlight.rgb,shine);
  fragColor=vec4(color*alpha,alpha)*qt_Opacity;
}
