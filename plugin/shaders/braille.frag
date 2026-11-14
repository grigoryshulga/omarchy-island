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
    float reveal;
    float style;
    vec4 impulseTimes;
    vec4 impulseStrengths;
    float backgroundStyle;
    vec4 paletteBlue;
    vec4 paletteGreen;
    vec4 paletteYellow;
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
    if (backgroundStyle > 0.5) {
        // Theme colors stay live. The same phase and audio envelope drive the
        // color field and dots, with no second timer, texture or audio process.
        vec2 p = sampleAt;
        float t = phase*0.18;
        float blendA;
        float blendB;
        if (backgroundStyle < 1.5) {
            // Aurora: elongated, gently folding curtains.
            float fold = p.y*3.0 + sin(p.x*5.0+t)*0.7 + sin(p.x*9.0-t*0.7)*0.2;
            blendA = 0.5+0.5*sin(fold*2.5+t);
            blendB = 0.5+0.5*cos(p.x*4.0+fold+t*0.6);
        } else if (backgroundStyle < 2.5) {
            // Tide: broad diagonal washes rolling past each other.
            blendA = 0.5+0.5*sin(p.x*3.0+p.y*4.0-t*1.3+bass*0.35);
            blendB = 0.5+0.5*sin(p.x*2.0-p.y*3.0+t*0.8);
        } else {
            // Plasma: soft interference lobes, no harsh color boundaries.
            vec2 q = (p-0.5)*4.0;
            float field = sin(q.x+t)+sin(q.y-t*1.2)+sin(length(q)*2.0-t*1.5);
            blendA = 0.5+0.5*sin(field+level*0.4);
            blendB = 0.5+0.5*cos(field*0.7+t);
        }
        vec3 cool = mix(paletteBlue.rgb,paletteGreen.rgb,blendA);
        vec3 warm = mix(accent.rgb,paletteYellow.rgb,blendB*0.65);
        cover = vec4(mix(cool,warm,blendB*0.7),1.0);
    }
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
    // Keep a gentle shimmer when the audio monitor is silent or unavailable.
    // Sound increases the glyph changes rather than enabling them from zero.
    float dots = mix(stableGlyph,glyph,mix(0.32,1.0,smoothstep(0.015,0.25,audio)));
    // Rare bright bits crossfade into new braille characters like glitter.
    float sparkle = mix(pow(a,18.0),pow(b,18.0),transition)*audio;
    // All styles light the same fixed dot lattice and sample the same cover.
    // Coordinates are isotropic in both the narrow clock and the popup.
    vec2 point = (cell*vec2(6.0,12.0)+center)/max(min(size.x,size.y),24.0);
    vec2 uv = sampleAt;
    float grain = noise(dotPosition,0u);
    if (style > 0.5) {
        float ink = 0.0;
        sparkle = 0.0;
        if (style < 1.5 || style > 4.5) {
            // Ripple: narrow traveling wavefronts. Echo: broad, lingering
            // impressions, whose centers and birth times belong to real attacks.
            ink = 0.11 + stableGlyph*0.16;
            for (int i=0;i<4;i++) {
                float age = phase-impulseTimes[i];
                uint seed = uint(max(0.0,impulseTimes[i])*1000.0);
                vec2 origin = vec2(0.15)+0.7*vec2(noise(uvec2(seed,7u),0u),noise(uvec2(seed,19u),0u));
                float distance = length((uv-origin)*size/max(min(size.x,size.y),24.0));
                float valid = step(0.0,age)*impulseStrengths[i];
                if (style < 1.5) {
                    float radius = age*0.65;
                    float edge = (distance-radius)/(0.045+treble*0.035);
                    ink += exp(-edge*edge)*exp(-max(age,0.0)*0.85)*valid*1.6;
                } else {
                    float radius = 0.12+age*0.13;
                    float edge = (distance-radius)/0.19;
                    float imprint = exp(-edge*edge)+0.35*exp(-distance*distance/0.12);
                    ink += imprint*exp(-max(age,0.0)*0.48)*valid;
                }
            }
            dots = clamp(ink,0.0,1.0);
        } else if (style < 2.5) {
            // Flow: curved lanes of light travel through stationary grains.
            float bend = sin(point.x*1.8+phase*0.32)*0.8 + sin(point.x*0.65-phase*0.21)*0.6;
            float lane = 0.5+0.5*sin(point.y*7.0+bend*3.0-phase*0.65);
            float current = 0.5+0.5*sin(point.x*3.0-point.y*1.5-phase*0.8+bass*0.3);
            dots = 0.12+pow(lane,5.0)*(0.28+current*0.6)*(0.5+audio*0.5);
            dots *= 0.55+grain*0.45;
        } else if (style < 3.5) {
            // Embers: localized heat blooms cool slowly after an attack.
            float heat = 0.0;
            for (int i=0;i<6;i++) {
                vec2 origin = vec2(noise(uvec2(i,31u),0u),noise(uvec2(i,61u),0u));
                vec2 delta = (uv-origin)*vec2(size.x/max(size.y,24.0),1.0);
                float breath = 0.5+0.5*sin(phase*0.7+float(i)*2.3);
                heat += exp(-dot(delta,delta)*22.0)*(0.14+breath*0.24+bass*0.5);
            }
            for (int i=0;i<4;i++) {
                float age = max(0.0,phase-impulseTimes[i]);
                uint seed = uint(max(0.0,impulseTimes[i])*1000.0);
                vec2 origin = vec2(noise(uvec2(seed,7u),0u),noise(uvec2(seed,19u),0u));
                vec2 delta = (uv-origin)*vec2(size.x/max(size.y,24.0),1.0);
                heat += exp(-dot(delta,delta)*15.0)*impulseStrengths[i]*exp(-age*0.55);
            }
            dots = clamp(0.08+heat*(0.35+grain*0.65),0.0,1.0);
            sparkle = pow(grain,24.0)*treble*heat*0.65;
        } else {
            // Constellations: small arcs cohere and loosen together. No lines
            // or moving particles; the grouping is expressed only by dot light.
            vec2 group = floor(point*1.8);
            vec2 localGroup = fract(point*1.8)-0.5;
            float seed = noise(uvec2(group),0u);
            float angle = seed*6.28318;
            float arc = abs(length(localGroup+vec2(sin(angle),cos(angle))*0.2)-0.33);
            float coherence = 0.5+0.5*sin(phase*0.55+seed*6.28318);
            float stars = smoothstep(0.72,0.95,grain);
            float chain = exp(-arc*arc*600.0)*smoothstep(0.25,0.65,grain);
            dots = 0.08+stars*0.25+chain*(0.2+coherence*0.4+audio*0.35);
            sparkle = stars*treble*coherence*0.35;
        }
    }
    // Each dot has a fixed disappearance threshold, independent of the music
    // shimmer. Reversing a tab gesture rebuilds the same field without noise
    // tiles or a new random pattern on every frame.
    float threshold = noise(dotPosition,0x5a17u);
    float survival = smoothstep(threshold,threshold+0.08,reveal*1.08);
    float radius = mix(0.40,1.08,survival);
    float mask = (1.0-smoothstep(radius,radius+0.32,length(local-center)))*survival;
    vec3 color = mix(cover.rgb,vec3(max(luminance,0.5)),0.20);
    color = mix(color,vec3(0.96),sparkle*0.8);
    color = mix(color,accent.rgb,mix(0.18,1.0,monochrome));
    float gain = mix(1.20,1.0,monochrome);
    float alpha = mask*clamp((dots*(0.26+audio*0.35)+sparkle*0.85)*gain,0.0,0.9);
    fragColor = vec4(color*alpha,alpha)*qt_Opacity;
}
