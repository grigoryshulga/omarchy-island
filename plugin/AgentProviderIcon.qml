import QtQuick
import Quickshell.Io
import qs.Commons

Item {
  id: root
  property string providerId: ""
  property color tint: Design.text
  readonly property var names: ({codex: "openai", "openai-api": "openai", claude: "claude",
    "opencode-go": "opencode", zai: "zai", deepseek: "deepseek", openrouter: "openrouter",
    "kimi-code": "kimi", moonshot: "moonshot", minimax: "minimax", gemini: "gemini"})
  readonly property string asset: Object.prototype.hasOwnProperty.call(names, providerId) ? names[providerId] : ""
  implicitWidth: Style.space(20)
  implicitHeight: implicitWidth
  Image {
    objectName: "agentProviderLogo"
    anchors.fill: parent
    sourceSize.width: width
    sourceSize.height: height
    fillMode: Image.PreserveAspectFit
    source: root.asset ? "data:image/svg+xml," + encodeURIComponent(svg.text().replace(/currentColor/g, String(root.tint))) : ""
  }
  FileView {
    id: svg
    path: root.asset ? String(Qt.resolvedUrl("vendor/lobe-icons/" + root.asset + ".svg")).replace(/^file:\/\//, "") : ""
    blockLoading: true
    printErrors: false
  }
}
