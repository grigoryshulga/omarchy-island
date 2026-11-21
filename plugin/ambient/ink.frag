#version 440
layout(location=0) in vec2 uv;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float cellScale;
    float fromMode;
    float toMode;
    float progress;
    vec4 paper;
    vec4 ink;
    vec4 highlight;
};
layout(binding=1) uniform sampler2D source;
layout(binding=2) uniform sampler2D atlas;
float luma(vec3 rgb) { return dot(rgb,vec3(.2126,.7152,.0722)); }

vec3 palette(int level) {
    if (level == 0) return paper.rgb;
    if (level == 1) return mix(paper.rgb,ink.rgb,.33);
    if (level == 2) return mix(paper.rgb,ink.rgb,.76);
    return mix(ink.rgb,highlight.rgb,.48);
}
vec3 renderMode(int mode) {
    if (mode == 0) return texture(source,uv).rgb;
    vec2 pixels = uv * size;
    if (mode == 1) {
        const int matrix[16] = int[16](0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5);
        float pitch = max(1.,cellScale*1.5);
        vec2 cell = floor(pixels/pitch);
        ivec2 tile = ivec2(cell) % 4;
        float tone = luma(texture(source,(cell+.5)*pitch/size).rgb);
        float t = clamp((sqrt(tone)-.13)*3.6,0.,3.);
        float rank = (float(matrix[tile.x+tile.y*4])+.5)/16.;
        int index = min(3,int(floor(t))+int(smoothstep(.20,.80,fract(t))>rank));
        return palette(index);
    }
    // Modified from pmndrs/postprocessing ASCIIEffect (zlib). A horizontal
    // bitmap atlas replaces the browser font canvas; see THIRD_PARTY.md.
    vec2 cellSize = vec2(6.,8.)*cellScale;
    vec2 grid = pixels/cellSize;
    vec2 center = (floor(grid)+.5)*cellSize/size;
    float light = luma(texture(source,center).rgb);
    int glyph = int(clamp(floor(sqrt(light)*10.),0.,9.));
    if (mode == 3) {
        // Choose a tangent glyph only on strong gradients of the original
        // artwork. Four neighboring samples suffice for this approximation.
        vec2 d = cellSize*.48/size;
        float gx = luma(texture(source,center+vec2(d.x,0)).rgb)-luma(texture(source,center-vec2(d.x,0)).rgb);
        float gy = luma(texture(source,center+vec2(0,d.y)).rgb)-luma(texture(source,center-vec2(0,d.y)).rgb);
        if (length(vec2(gx,gy))>.115) {
            if (abs(gx)>2.4*abs(gy)) glyph=10;
            else if (abs(gy)>2.4*abs(gx)) glyph=11;
            else glyph=gx*gy>0. ? 12 : 13;
            light=max(light,.64);
        }
    }
    float mask=texture(atlas,vec2((float(glyph)+fract(grid.x))/14.,fract(grid.y))).r;
    return mix(paper.rgb,mix(ink.rgb,highlight.rgb,.34*light),mask*(.34+.66*sqrt(light)));
}
void main() {
    int a=int(fromMode+.5), b=int(toMode+.5);
    vec3 c = a==b || progress<=0. ? renderMode(a) : progress>=1. ? renderMode(b) : mix(renderMode(a),renderMode(b),progress);
    fragColor=vec4(c*qt_Opacity,qt_Opacity);
}
