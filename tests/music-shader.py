#!/usr/bin/env python3
"""Render the shipped fragment source with surfaceless EGL; no desktop windows.

Requires PyOpenGL and an EGL driver supporting OpenGL 4.4.
"""
from session import ensure
ensure()
import os
os.environ['PYOPENGL_PLATFORM'] = 'egl'
os.environ['EGL_PLATFORM'] = 'surfaceless'
from ctypes import c_int, byref, cast, POINTER, c_char
from pathlib import Path
import struct
from OpenGL.EGL import *
from OpenGL.GL import *
from OpenGL.GL.shaders import compileProgram, compileShader

display = eglGetDisplay(EGL_DEFAULT_DISPLAY)
major, minor = c_int(), c_int()
assert eglInitialize(display, byref(major), byref(minor)), 'No EGL display'
assert eglBindAPI(EGL_OPENGL_API)
attributes = (c_int * 7)(EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
                       EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT, EGL_RED_SIZE, 8, EGL_NONE)
configs, count = (EGLConfig * 1)(), c_int()
assert eglChooseConfig(display, attributes, configs, 1, byref(count)) and count.value
surface = eglCreatePbufferSurface(display, configs[0],
    (c_int * 5)(EGL_WIDTH, 360, EGL_HEIGHT, 180, EGL_NONE))
context = eglCreateContext(display, configs[0], EGL_NO_CONTEXT,
    (c_int * 5)(0x3098, 4, 0x30fb, 4, EGL_NONE))
assert eglMakeCurrent(display, surface, surface, context)
try:
    fragment = (Path(__file__).resolve().parents[1] / 'plugin/shaders/braille.frag').read_text()
    program = compileProgram(compileShader('''#version 440
layout(location=0) out vec2 qt_TexCoord0;
void main() {
    vec2 p=vec2((gl_VertexID<<1)&2,gl_VertexID&2);
    qt_TexCoord0=p;
    gl_Position=vec4(p*2.0-1.0,0.0,1.0);
}''', GL_VERTEX_SHADER), compileShader(fragment, GL_FRAGMENT_SHADER))
    glUseProgram(program)
    vao = glGenVertexArrays(1)
    glBindVertexArray(vao)
    texture = glGenTextures(1)
    glActiveTexture(GL_TEXTURE1)
    glBindTexture(GL_TEXTURE_2D, texture)
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, bytes([255]*4))
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    buffer = glGenBuffers(1)
    glBindBuffer(GL_UNIFORM_BUFFER, buffer)
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, buffer)
    # Match the shader's std140 uniform block. Get the compiled offsets so new
    # uniforms/reordering cannot silently make the fixture send wrong values.
    names = ['qt_Opacity', 'size', 'phase', 'level', 'bass', 'treble', 'accent',
             'monochrome', 'reveal', 'style', 'impulseTimes', 'impulseStrengths',
             'backgroundStyle', 'paletteBlue', 'paletteGreen', 'paletteYellow']
    from ctypes import c_char_p, c_uint
    indices = (c_uint * len(names))()
    glGetUniformIndices(program, len(names), cast((c_char_p * len(names))(*[n.encode() for n in names]), POINTER(POINTER(c_char))), indices)
    assert all(index != GL_INVALID_INDEX for index in indices), 'Missing shader uniform'
    offsets = (c_int * len(names))()
    glGetActiveUniformsiv(program, len(names), indices, GL_UNIFORM_OFFSET, offsets)
    layout = dict(zip(names, offsets))

    def frame(phase, width, height, level, style=4, raw=False):
        data = bytearray(512)
        values = {'qt_Opacity':[0.7], 'size':[width,height], 'phase':[phase],
                  'level':[level], 'bass':[level], 'treble':[0], 'accent':[1,1,1,1],
                  'monochrome':[1 if height == 26 else 0], 'reveal':[1], 'style':[style],
                  'impulseTimes':[-10]*4, 'impulseStrengths':[0]*4,
                  'backgroundStyle':[0], 'paletteBlue':[0.2,0.4,0.8,1],
                  'paletteGreen':[0.2,0.8,0.4,1], 'paletteYellow':[0.8,0.6,0.2,1]}
        for name, value in values.items():
            struct.pack_into(f'{len(value)}f', data, layout[name], *value)
        glBufferData(GL_UNIFORM_BUFFER, len(data), bytes(data), GL_DYNAMIC_DRAW)
        glViewport(0,0,width,height)
        glDrawArrays(GL_TRIANGLES,0,3)
        pixels = glReadPixels(0,0,width,height,GL_RGBA,GL_UNSIGNED_BYTE)
        if raw:
            return pixels
        # Dot centers only: the transparent gaps must not dilute the signal.
        return [pixels[(y*width+x)*4] for y in range(1,height,3) for x in range(1,width,3)]

    for width,height in [(360,180),(240,26)]:
        for level in [0,0.4]:
            for phase in [0,20,120]:
                first = frame(phase,width,height,level)
                second = frame(phase+1,width,height,level)
                changed = sum(abs(a-b)>=6 for a,b in zip(first,second))/len(first)
                print(f'Constellations {width}x{height}, level={level}, t={phase}: {changed:.1%} visibly changed dots')
                assert changed >= 0.15, 'Constellations appear static: too few dots visibly evolve over one second'
    assert frame(0,360,180,0.4) == frame(0,360,180,0.4), 'Fixed phase is not deterministic'
    def cover(rgb):
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, bytes([*rgb,255]))

    for height in [26,180]:
        cover((128,128,128))
        width = 240
        quiet = frame(0,width,height,0,6,raw=True)
        for other in [frame(1.4,width,height,0,6,raw=True), frame(0,width,height,0.8,6,raw=True)]:
            changed = sum(abs(a-b)>=3 for a,b in zip(quiet[::4],other[::4]))
            assert changed > width*height*0.1, 'Print did not react visibly to the clock or bass'
        cover((100,100,100))
        quiet = frame(0,width,height,0,6,raw=True)
        # Interior samples have a ten-pixel repeat (four fixed Bayer cells).
        for y in (0,1,5,6):
            for x in range(0,100,10):
                start = (y*width+x)*4
                row = quiet[start:start+40:4]
                assert min(row[0:2])>25 and max(row[3:5])<25 and min(row[5:7])>25 and max(row[8:10])<25, 'Unexpected print pitch'

    for height in [26,180]:
        for rgb,sign in [((239,70,48),1),((36,116,223),-1)]:
            cover(rgb)
            pixel = frame(0,240,height,0,6,raw=True)[:4]
            assert sign*(pixel[0]-pixel[2])>=5, 'Print lost the cover hue'
    print('MUSIC_SHADER_PASS')
finally:
    eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT)
    eglDestroyContext(display, context)
    eglDestroySurface(display, surface)
    eglTerminate(display)
