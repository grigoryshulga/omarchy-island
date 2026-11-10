#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; float horizontal; vec2 size; float cornerRadius; };
layout(binding = 1) uniform sampler2D source;
void main() {
  // A broad ellipse starts at the top-center of the cover. Keep its core
  // brighter for longer, then ease both the sides and bottom into darkness.
  float fade = 1.0 - smoothstep(0.30,1.0,qt_TexCoord0.y);
  vec2 coverEllipse = vec2((qt_TexCoord0.x-0.5)/0.78,qt_TexCoord0.y/1.15);
  float radialFade = 1.0-smoothstep(0.20,1.16,length(coverEllipse));
  fade *= mix(1.0,radialFade,0.70);
  float sideFade = smoothstep(0.0,0.16,qt_TexCoord0.x)*(1.0-smoothstep(0.84,1.0,qt_TexCoord0.x));
  vec2 ellipse = vec2((qt_TexCoord0.x-0.5)/0.55,qt_TexCoord0.y/1.10);
  sideFade *= 1.0-smoothstep(0.10,1.05,length(ellipse));
  vec2 box = abs((qt_TexCoord0-0.5)*size)-(size*0.5-vec2(cornerRadius));
  float sdf = length(max(box,vec2(0.0)))+min(max(box.x,box.y),0.0)-cornerRadius;
  float roundedClip = 1.0-smoothstep(-0.5,0.5,sdf);
  fragColor = texture(source, qt_TexCoord0) * mix(fade,sideFade,horizontal) * roundedClip * qt_Opacity;
}
