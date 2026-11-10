#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 size;
  float amount;
  vec4 accent;
};
layout(binding = 1) uniform sampler2D source;

uint mixBits(uint value) {
  value ^= value >> 16; value *= 0x85ebca6bu;
  value ^= value >> 13; value *= 0xc2b2ae35u;
  return value ^ (value >> 16);
}

void main() {
  vec4 original = texture(source,qt_TexCoord0);
  vec2 pixel = qt_TexCoord0*size;
  vec2 site = floor(pixel/3.0);
  vec2 center = (site+0.5)*3.0;
  vec2 safeSize = max(size,vec2(1.0));
  // Keep thin stems: taking the strongest nearby ink sample avoids losing
  // a one-pixel line just because it falls between lattice sites.
  vec4 ink = texture(source,center/safeSize);
  ink = max(ink,texture(source,(center+vec2(1.0,0.0))/safeSize));
  ink = max(ink,texture(source,(center-vec2(1.0,0.0))/safeSize));
  ink = max(ink,texture(source,(center+vec2(0.0,1.0))/safeSize));
  ink = max(ink,texture(source,(center-vec2(0.0,1.0))/safeSize));
  float noise = float(mixBits(mixBits(uint(site.x)) ^ mixBits(uint(site.y)+0x9e3779b9u)) >> 8)/16777216.0;
  float radius = mix(0.74,1.08,noise);
  float dot = 1.0-smoothstep(radius,radius+0.24,length(pixel-center));
  ink.rgb = mix(ink.rgb,accent.rgb*ink.a,0.18);
  vec4 braille = ink*dot;
  fragColor = mix(original,braille,clamp(amount,0.0,1.0))*qt_Opacity;
}
