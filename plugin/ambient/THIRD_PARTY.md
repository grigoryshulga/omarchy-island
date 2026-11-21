# Shader attribution

The cell-centred brightness sampling and atlas lookup in ink.frag are adapted from [pmndrs/postprocessing ASCIIEffect](https://github.com/pmndrs/postprocessing/blob/a1f103559d15cf56cbcbb15d4373711b09418f3f/src/effects/glsl/ascii.frag), under the [zlib license](LICENSE.pmndrs). This altered version targets Qt Shader Tools, uses a hand-drawn horizontal atlas and adds palette mapping, directional strokes and transitions.

Directional strokes are inspired by [Garrett Gunnell’s AcerolaFX ASCII shader](https://github.com/GarrettGunnell/AcerolaFX/blob/c33f779b093fa1e25faf0c77ef22c3fe6902e2fe/Shaders/AcerolaFX_ASCII.fx). The gradient estimator, original bitmap atlas, QML and four-tone shading were written for this project.
