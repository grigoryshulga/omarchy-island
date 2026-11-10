#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float phase;
    float level;
    float bass;
    float treble;
    vec4 accent;
    float monochrome;
};
layout(binding = 1) uniform sampler2D source;
// Integer avalanche hashing avoids the precision stripes and small spatial
// periods of a sine hash. Dot coordinates are never wrapped into noise tiles.
uint mixBits(uint v) {
    v ^= v >> 16; v *= 0x85ebca6bu;
    v ^= v >> 13; v *= 0xc2b2ae35u;
    return v ^ (v >> 16);
}
float noise(uvec2 position, uint frame) {
    return float(mixBits(mixBits(position.x ^ 0x9e3779b9u) ^ mixBits(position.y ^ 0x68bc21ebu) ^ mixBits(frame ^ 0x02e5be93u)) >> 8) / 16777216.0;
}
void main() {
    vec2 pixel = qt_TexCoord0 * size;
    // Continuous dot pitch: the 2x4 braille cells have no extra gutters.
    vec2 cell = floor(pixel / vec2(6.0,12.0));
    vec2 local = mod(pixel,vec2(6.0,12.0));
    vec2 dotIndex = clamp(floor(local/3.0),vec2(0.0),vec2(1.0,3.0));
    vec2 center = vec2(1.5)+dotIndex*3.0;
    vec2 sampleAt = (cell*vec2(6.0,12.0)+center)/size;
    vec4 cover = texture(source,clamp(sampleAt,vec2(0.01),vec2(0.99)));
    float luminance = mix(dot(cover.rgb,vec3(0.2126,0.7152,0.0722)),0.5,monochrome);
    // Unicode braille bit order: 1 4 / 2 5 / 3 6 / 7 8. Changing these
    // eight bits changes the glyph, while its location and color stay put.
    uvec2 dotPosition = uvec2(cell)*uvec2(2u,4u)+uvec2(dotIndex);
    // Each cell has its own fractional update phase, removing a global pulse.
    float clock = phase*3.6+noise(uvec2(cell),0u);
    uint tick = uint(floor(clock));
    float transition = smoothstep(0.0,1.0,fract(clock));
    float coverage = clamp(0.16+luminance*0.72,0.16,0.88);
    float a = noise(dotPosition,tick+1u);
    float b = noise(dotPosition,tick+2u);
    float glyph = mix(step(1.0-coverage,a),step(1.0-coverage,b),transition);
    float stableGlyph = step(1.0-coverage,noise(dotPosition,0u));
    float audio = clamp(level*0.75+bass*0.35+treble*0.15,0.0,1.0);
    float dots = mix(stableGlyph,glyph,smoothstep(0.015,0.25,audio));
    // Rare bright bits crossfade into new braille characters like glitter.
    float sparkle = mix(pow(a,18.0),pow(b,18.0),transition)*audio;
    float mask = 1.0-smoothstep(1.08,1.40,length(local-center));
    vec3 color = mix(cover.rgb,vec3(max(luminance,0.5)),0.20);
    color = mix(color,vec3(0.96),sparkle*0.8);
    color = mix(color,accent.rgb,mix(0.18,1.0,monochrome));
    float alpha = mask*clamp(dots*(0.26+audio*0.35)+sparkle*0.85,0.0,0.9);
    fragColor = vec4(color*alpha,alpha)*qt_Opacity;
}
