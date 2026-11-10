#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  float phase;
  float condition;
  float night;
  vec4 accent;
  vec4 foreground;
  vec4 muted;
};
uint mixBits(uint v) { v^=v>>16;v*=0x85ebca6bu;v^=v>>13;v*=0xc2b2ae35u;return v^(v>>16); }
float hash(uvec2 p,uint salt) { return float(mixBits(mixBits(p.x)^mixBits(p.y+0x9e3779b9u)^mixBits(salt))>>8)/16777216.0; }
float disk(vec2 p,vec2 center,float radius) { return 1.0-smoothstep(radius-0.012,radius+0.012,length(p-center)); }
float segment(vec2 p,vec2 a,vec2 b,float radius) { vec2 ab=b-a;float t=clamp(dot(p-a,ab)/max(dot(ab,ab),0.00001),0.0,1.0);return 1.0-smoothstep(radius,radius+0.012,length(p-a-ab*t)); }
float cloud(vec2 p,vec2 at,float scale) {
  vec2 q=(p-at)/scale;
  float d=min(length(q-vec2(-0.19,0.0))-0.14,length(q-vec2(0.0,-0.07))-0.20);
  d=min(d,length(q-vec2(0.19,0.0))-0.14);
  vec2 box=abs(q-vec2(0.0,0.04))-vec2(0.22,0.04);
  d=min(d,length(max(box,vec2(0.0)))+min(max(box.x,box.y),0.0)-0.065);
  return 1.0-smoothstep(-0.006,0.012,d);
}
void main() {
  vec2 pixel=qt_TexCoord0*size;
  vec2 site=floor(pixel/3.0),local=mod(pixel,3.0)-vec2(1.5);
  vec2 p=(site*3.0+vec2(1.5)-size*0.5)/max(1.0,min(size.x,size.y));
  uvec2 id=uvec2(site);
  float t=phase;
  vec3 warm=mix(vec3(1.0,0.76,0.34),accent.rgb,0.26);
  vec3 cool=mix(vec3(0.40,0.67,0.96),accent.rgb,0.30);
  vec3 cloudColor=mix(foreground.rgb,accent.rgb,0.25);
  vec3 color=cloudColor;
  float shape=0.0;
  bool cloudy=condition>=1.0;
  if(condition<1.5) {
    vec2 at=condition>0.5 ? vec2(-0.17,-0.14) : vec2(0.0,-0.035);
    vec2 q=p-at;float r=length(q);
    if(night>0.5) {
      shape=disk(p,at,0.175)*(1.0-disk(p,at+vec2(0.077,-0.045),0.158));
      color=mix(foreground.rgb,cool,0.32);
      for(int i=0;i<5;i++) {
        float k=float(i);vec2 star=vec2(sin(k*4.8)*0.35,-0.28+fract(k*0.37)*0.42);
        float gleam=(segment(p,star-vec2(0.012,0),star+vec2(0.012,0),0.003)+segment(p,star-vec2(0,0.012),star+vec2(0,0.012),0.003))*0.5;
        shape=max(shape,gleam*(0.62+0.20*sin(t*0.8+k)));
      }
    } else {
      float angle=atan(q.y,q.x)+t*0.055;
      float rays=pow(max(0.0,cos(angle*12.0)),14.0)*(smoothstep(0.205,0.225,r)-smoothstep(0.29,0.32,r));
      shape=max(disk(p,at,0.172+0.003*sin(t*1.1)),rays);
      color=warm;
    }
  }
  if(cloudy) {
    float bob=0.009*sin(t*0.55);
    vec2 at=condition>=4.0 ? vec2(0.0,-0.14+bob) : vec2(0.04,0.015+bob);
    if(condition==2.0) {
      float back=cloud(p,vec2(-0.12,-0.105-bob),0.78);
      shape=max(shape,back*0.48);
    }
    float front=cloud(p,at,condition==1.0 ? 0.83 : 1.0);
    color=mix(color,cloudColor*(0.83+0.17*(1.0-smoothstep(-0.26,0.15,p.y))),front);
    shape=max(shape,front);
    if(condition==3.0) {
      for(int i=0;i<3;i++) {
        float k=float(i);float x=sin(t*0.28+k)*0.025;
        shape=max(shape,segment(p,vec2(-0.32+x,0.15+k*0.075),vec2(0.30+x,0.15+k*0.075),0.012)*(0.75-k*0.15));
      }
    }
  }
  if(condition>=4.0 && condition<=7.0) {
    float drops=0.0;
    for(int i=0;i<9;i++) {
      float k=float(i),seed=hash(uvec2(uint(i),1u),9u);
      float cycle=fract(t*(condition==6.0 ? 0.15 : 0.48)+seed);
      vec2 at=vec2(-0.29+k*0.072,0.04+cycle*0.39);
      float fade=smoothstep(0.0,0.12,cycle)*(1.0-smoothstep(0.76,1.0,cycle));
      if(condition==6.0) {
        at.x+=sin(t*0.7+k*2.2)*0.025;
        float snow=segment(p,at-vec2(0.018,0),at+vec2(0.018,0),0.003);
        snow=max(snow,segment(p,at-vec2(0,0.018),at+vec2(0,0.018),0.003));
        drops=max(drops,snow*fade);
      } else {
        float len=condition==4.0 ? 0.020 : 0.045;
        drops=max(drops,segment(p,at,at+vec2(-len*0.28,len),0.005)*fade);
      }
    }
    color=mix(color,condition==6.0 ? mix(foreground.rgb,cool,0.22) : cool,clamp(drops,0.0,1.0));
    shape=max(shape,drops);
    if(condition==7.0) {
      float lightning=max(segment(p,vec2(0.04,0.035),vec2(-0.02,0.14),0.014),segment(p,vec2(-0.02,0.14),vec2(0.06,0.14),0.014));
      lightning=max(lightning,segment(p,vec2(0.06,0.14),vec2(-0.02,0.28),0.014));
      lightning*=0.6+0.3*pow(max(0.0,sin(t*1.4)),8.0);
      color=mix(color,warm,lightning);shape=max(shape,lightning);
    }
  }
  float core=1.0-smoothstep(0.05,0.55,length(p-vec2(0,-0.045)));
  float radius=mix(0.50,1.20,core);
  float dotMask=1.0-smoothstep(radius,radius+0.24,length(local));
  float clock=t*1.7+hash(id,71u),blend=smoothstep(0.0,1.0,fract(clock));
  float coverage=0.52+core*0.36;
  float a=hash(id,uint(floor(clock))),b=hash(id,uint(floor(clock))+1u);
  float glyph=mix(step(1.0-coverage,a),step(1.0-coverage,b),blend);
  float alpha=dotMask*glyph*shape*(0.68+0.15*core);
  fragColor=vec4(color*alpha,alpha)*qt_Opacity;
}
