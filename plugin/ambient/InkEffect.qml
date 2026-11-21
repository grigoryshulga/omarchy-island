import QtQuick

ShaderEffect {
    id: effect
    property var source: null
    property color paper: "#131516"
    property color ink: "#819890"
    property color highlight: "#f8ebe3"
    property real fromMode: 1
    property real toMode: fromMode
    property real progress: 1
    property real cellScale: 1
    readonly property vector2d size: Qt.vector2d(Math.max(1,width),Math.max(1,height))
    property var atlas: Image {
        source: Qt.resolvedUrl("atlas.png")
        smooth: false
        visible: false
    }
    vertexShader: Qt.resolvedUrl("ink.vert.qsb")
    fragmentShader: Qt.resolvedUrl("ink.frag.qsb")
}
