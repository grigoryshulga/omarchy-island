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
  float artworkMix;
  vec4 focusRect;
  float focusRadius;
  float focused;
  vec4 trail0;
  vec4 trail1;
  vec4 trail2;
  vec4 trail3;
  vec4 trail4;
  vec4 trail5;
  vec4 trail6;
  vec4 trail7;
  vec4 trail8;
  vec4 trail9;
  vec4 trail10;
  vec4 trail11;
  vec4 trail12;
  vec4 trail13;
  vec4 trail14;
  vec4 trail15;
  vec4 trail16;
  vec4 trail17;
  vec4 trail18;
  vec4 trail19;
  vec4 trail20;
  vec4 trail21;
  vec4 trail22;
  vec4 trail23;
  vec4 edgeImpact;
  float edgeProgress;
  float edgeEnabled;
  vec4 neighbor0;
  vec4 neighbor1;
  vec4 neighbor2;
  vec4 neighbor3;
  vec4 neighborRadii;
  vec4 neighborPowers;
  float cornerPower;
  float focusPower;
  float buttonHovered;
  float bloomStrength;
  vec4 rippleBounds;
  vec2 rippleCorner;
};
layout(binding = 1) uniform sampler2D source;
uint mixBits(uint v) {
  v ^= v >> 16; v *= 0x85ebca6bu;
  v ^= v >> 13; v *= 0xc2b2ae35u;
  return v ^ (v >> 16);
}
float noise(uvec2 position, uint frame) {
  return float(mixBits(mixBits(position.x ^ 0x9e3779b9u) ^ mixBits(position.y ^ 0x68bc21ebu) ^ mixBits(frame ^ 0x02e5be93u)) >> 8) / 16777216.0;
}
vec2 dots(vec2 local,float core,float a,float b,float blend) {
  // The pitch never changes: profile affects radius and how many fixed sites
  // are lit, not the coordinates of the lattice or its spacing.
  float radius=mix(1.08,mix(0.45,1.25,core),profile);
  float softness=mix(0.32,0.22,profile);
  float coverage=mix(0.60,mix(0.18,0.90,core),profile);
  float pattern=mix(step(1.0-coverage,a),step(1.0-coverage,b),blend);
  float distanceFromDot=length(local);
  float ink=1.0-smoothstep(radius,radius+softness,distanceFromDot);
  float bloom=1.0-smoothstep(radius*0.65,min(1.5,radius+0.78),distanceFromDot);
  return vec2(ink,max(0.0,bloom-ink))*pattern;
}
float roundedDistance(vec2 pixel, vec4 rect, float radius, float power) {
  vec2 halfSize=rect.zw*0.5;
  float r=clamp(radius,0.0,min(halfSize.x,halfSize.y));
  vec2 box=abs(pixel-rect.xy-halfSize)-(halfSize-vec2(r));
  if(power==2.0) return length(max(box,vec2(0.0)))+min(max(box.x,box.y),0.0)-r;
  vec2 q=max(box,vec2(0.0));
  float scale=max(q.x,q.y);
  float norm=scale>0.0 ? scale*pow(pow(q.x/scale,power)+pow(q.y/scale,power),1.0/power) : 0.0;
  return norm+min(max(box.x,box.y),0.0)-r;
}
float clickRing(float distanceFromClick,float radius,float width) {
  float band=(distanceFromClick-radius)/width;
  return exp(-band*band);
}
float clickTravel(float progress) {
  float remaining=1.0-progress;
  return 1.0-remaining*remaining*remaining;
}
void main() {
  vec2 pixel=qt_TexCoord0*size;
  vec2 delta=pixel-center;
  float angle=atan(delta.y,delta.x);
  float edge=1.0+0.045*sin(angle*3.0+phase*0.8)+0.025*sin(angle*7.0-phase*0.6)+0.012*sin(angle*11.0+phase*0.3);
  float radius=spotRadius*mix(1.0,0.58,focused);
  float normalized=length(delta)/(radius*edge);
  // A rounded brightness profile avoids a flat hot center and abrupt shoulder.
  float falloff=exp(-3.2*normalized*normalized)*(1.0-smoothstep(0.75,1.35,normalized));
  float core=exp(-3.0*normalized*normalized);
  vec2 local=mod(pixel,3.0)-vec2(1.5);
  uvec2 site=uvec2(floor(pixel/3.0));
  float clock=phase*1.8+noise(site,17u);
  uint frame=uint(floor(clock));
  float a=noise(site,frame), b=noise(site,frame+1u);
  float blend=smoothstep(0.0,1.0,fract(clock));
  // Draw the actual recent path, with softly fading overlapping footprints.
  vec4 samples[24]=vec4[24](trail0,trail1,trail2,trail3,trail4,trail5,trail6,trail7,trail8,trail9,trail10,trail11,trail12,trail13,trail14,trail15,trail16,trail17,trail18,trail19,trail20,trail21,trail22,trail23);
  float wake=0.0;
  float wakeWidth=max(1.0,radius*0.42);
  for(int i=0;i<24;i++) {
    if(samples[i].z<=0.0) continue;
    vec2 offset=pixel-samples[i].xy;
    float footprint=exp(-dot(offset,offset)/(wakeWidth*wakeWidth));
    wake=max(wake,footprint*samples[i].z*0.85);
  }
  float field=falloff+wake*(1.0-falloff);
  float boundary=roundedDistance(pixel,focusRect,focusRadius,focusPower);
  float depth=max(0.0,-boundary);
  float rim=exp(-depth*depth/32.0)*focused;
  vec2 hoverDots=dots(local,max(core,wake),a,b,blend);
  float ink=hoverDots.x;
  float alpha=ink*field*hoverOpacity*mix(0.18,0.85,focused);
  alpha+=wake*hoverOpacity*mix(0.025,0.08,focused);
  // Stronger focused dots and inner bloom stay within the same compact mask.
  alpha+=field*rim*hoverOpacity*(0.24+ink*0.55);
  alpha+=hoverDots.y*bloomStrength*field*hoverOpacity*mix(0.45,1.0,focused);
  alpha+=buttonHovered*hoverOpacity*exp(-6.0*normalized*normalized)*(ink*0.13+hoverDots.y*bloomStrength*0.34);

  // A collision splits into small pixels travelling both ways along the rim.
  // Project their centers inward so rounded corners guide the spread too.
  if(edgeEnabled>0.0 && edgeProgress<1.0) {
    vec2 normal=edgeImpact.zw;
    vec2 tangent=vec2(-normal.y,normal.x);
    float travel=1.0-pow(1.0-edgeProgress,2.0);
    float fade=smoothstep(0.0,0.08,edgeProgress)*(1.0-smoothstep(0.18,1.0,edgeProgress));
    for(int i=0;i<14;i++) {
      float seed=noise(uvec2(uint(i),23u),7u);
      float direction=(i%2==0) ? -1.0 : 1.0;
      float along=direction*(6.0+seed*40.0)*travel;
      float inward=2.0+noise(uvec2(uint(i),31u),9u)*9.0*sin(edgeProgress*3.14159);
      vec2 particle=edgeImpact.xy+tangent*along-normal*inward;
      float d=roundedDistance(particle,focusRect,focusRadius,focusPower);
      vec2 gradient=vec2(
        roundedDistance(particle+vec2(0.5,0.0),focusRect,focusRadius,focusPower)-roundedDistance(particle-vec2(0.5,0.0),focusRect,focusRadius,focusPower),
        roundedDistance(particle+vec2(0.0,0.5),focusRect,focusRadius,focusPower)-roundedDistance(particle-vec2(0.0,0.5),focusRect,focusRadius,focusPower));
      particle-=gradient/max(length(gradient),0.001)*max(0.0,d+2.0);
      vec2 offset=pixel-particle;
      float square=1.0-smoothstep(0.65+seed*0.60,1.45+seed*0.60,max(abs(offset.x),abs(offset.y)));
      float halo=exp(-dot(offset,offset)/12.0)*0.07;
      alpha+=(square*0.65+halo)*fade*edgeEnabled*hoverOpacity;
    }
  }

  float distanceToEdge=roundedDistance(pixel,vec4(0.0,0.0,size),cornerRadius,cornerPower);
  float mask=1.0-smoothstep(-1.0,0.0,distanceToEdge);
  float outerMask=mask;
  // The antialias band is entirely inside the surface, including square corners.
  mask*=mix(1.0,1.0-smoothstep(-1.0,0.0,boundary),focused);
  alpha=clamp(alpha,0.0,1.0)*mask;
  if(rippleProgress<1.0) {
    bool onSurface=rippleBounds.z>0.0 && rippleBounds.w>0.0;
    float clip=onSurface
      ? 1.0-smoothstep(-1.0,0.0,roundedDistance(pixel,rippleBounds,rippleCorner.x,rippleCorner.y)) : 1.0;
    vec2 farthest=onSurface ? max(rippleCenter-rippleBounds.xy,rippleBounds.xy+rippleBounds.zw-rippleCenter)
                            : max(rippleCenter,size-rippleCenter);
    float reach=clamp(length(farthest),1.0,max(1.0,spotRadius*1.6));
    float distanceFromClick=length(pixel-rippleCenter);
    float waveWidth=clamp(spotRadius*0.045,2.0,4.5);
    float tail=clamp((rippleProgress-0.15)/0.85,0.0,1.0);
    float first=clickRing(distanceFromClick,reach*clickTravel(rippleProgress),waveWidth);
    float second=clickRing(distanceFromClick,reach*clickTravel(tail),waveWidth*1.35)*smoothstep(0.0,0.14,tail);
    float flashRadius=max(1.0,min(reach*0.46,spotRadius*0.24));
    float flash=exp(-distanceFromClick*distanceFromClick/(flashRadius*flashRadius))*(1.0-smoothstep(0.0,0.36,rippleProgress));
    float fade=1.0-smoothstep(0.04,0.97,rippleProgress);
    vec2 clickDots=dots(local,0.92,a,b,blend);
    float response=(first*0.53+second*0.22)*fade+flash*0.46;
    alpha+=(clickDots.x+clickDots.y*bloomStrength*1.6)*response*clip*outerMask;
  }
  // Neighbor rims catch the same light, independently of the focused mask.
  // Only a narrow inner bloom is drawn: gaps and nested containers stay clear.
  vec4 neighbors[4]=vec4[4](neighbor0,neighbor1,neighbor2,neighbor3);
  float sharedGlow=0.0;
  float neighborReach=max(1.0,spotRadius*0.75);
  float proximity=1.0-smoothstep(0.0,neighborReach,length(delta));
  for(int i=0;i<4;i++) {
    if(neighbors[i].z<=0.0 || neighbors[i].w<=0.0) continue;
    float d=roundedDistance(pixel,neighbors[i],neighborRadii[i],neighborPowers[i]);
    float innerMask=1.0-smoothstep(-1.0,0.0,d);
    float bloom=exp(-d*d/18.0)*innerMask;
    sharedGlow=max(sharedGlow,bloom*proximity*(0.28+ink*0.35));
  }
  alpha=clamp(alpha+sharedGlow*hoverOpacity*outerMask,0.0,1.0);
  // Keep music feedback in the cover's colors, with the same 18% theme tint
  // as the music backdrop. Other surfaces retain the pure theme accent.
  vec4 cover=texture(source,(vec2(site)*3.0+vec2(1.5))/size);
  float luminance=dot(cover.rgb,vec3(0.2126,0.7152,0.0722));
  vec3 artColor=mix(cover.rgb,vec3(max(luminance,0.5)),0.20);
  artColor=mix(artColor,accent.rgb,0.18);
  vec3 color=mix(accent.rgb,artColor,artworkMix*cover.a);
  fragColor=vec4(color*alpha,alpha)*qt_Opacity;
}
