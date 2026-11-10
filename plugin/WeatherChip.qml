import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "WeatherModel.js" as Model

FeedbackButton {
  id: root
  required property var weather
  required property var strings
  property bool showLabel: false
  readonly property var current: weather && weather.report ? weather.report.current : null
  implicitWidth: content.implicitWidth+Style.space(12)
  implicitHeight: Style.space(30)
  radius: Math.min(Style.cornerRadius,Style.space(6))
  tooltipText: strings.t("weather.open")
  focusable: true
  RowLayout {
    id: content
    anchors.centerIn: parent
    width: Math.min(implicitWidth,Math.max(0,root.width-Style.space(12)))
    spacing: Style.space(2)
    PlainText { Layout.fillWidth: true; Layout.minimumWidth: 0; visible: root.showLabel; text: root.strings.t("weather.open"); color: root.selected ? Commons.Color.accent : Commons.Color.foreground; font.pixelSize: Style.font.bodySmall }
    WeatherScene { Layout.preferredWidth: Style.space(root.showLabel ? 22 : 32); Layout.preferredHeight: Style.space(28); condition: root.current ? Model.kind(root.current.code) : 2; isDay: root.current ? root.current.isDay : true; animated: false; opacity: root.current ? 1 : 0.35 }
    PlainText { text: root.current ? Commons.I18n.formatNumber(Model.temperature(root.current.temperature,root.weather.useImperial))+"°" : root.weather && root.weather.loading ? "…" : "—"; color: root.selected ? Commons.Color.accent : Commons.Color.foreground; font.pixelSize: Style.font.bodySmall }
  }
}
