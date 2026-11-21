#version 440
layout(location=0) in vec4 qt_Vertex;
layout(location=1) in vec2 qt_MultiTexCoord0;
layout(location=0) out vec2 uv;
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
void main(){uv=qt_MultiTexCoord0; gl_Position=qt_Matrix*qt_Vertex;}
