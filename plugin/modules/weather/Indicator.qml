import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../.." as Island
import "../../WeatherModel.js" as Weather

Island.ModuleView {
  id:root
  objectName:"islandWeatherIndicator"
  available:!!backend && backend.allowed
  readonly property var current:backend && backend.report ? backend.report.current : null
  readonly property string unit:backend ? backend.temperatureUnit : "celsius"
  readonly property var temperature:current ? Weather.temperature(current.temperature,unit) : null
  readonly property string temperatureText:temperature===null ? "—" : Commons.I18n.formatNumber(temperature)+(unit==="kelvin" ? " K" : "°")
  readonly property bool stale:!!backend && !!backend.stale && !!current
  tooltip:presentation.strings.t("weather.open")+(temperature===null ? "" : " · "+Commons.I18n.formatNumber(temperature)+Weather.unitSymbol(unit))+(stale ? " · "+presentation.strings.t("weather.stale") : "")
  implicitWidth:presentation.vertical ? Math.min(presentation.barSize-Style.space(4),content.implicitWidth) : content.implicitWidth
  implicitHeight:presentation.vertical ? content.implicitHeight : presentation.barHeight
  // The existing shared service owns refreshes; multiple monitors never create collectors.
  function activate() {if(backend && backend.allowed && !backend.activated) backend.activate()}
  onBackendChanged:Qt.callLater(activate)
  Connections {target:root.backend;function onAllowedChanged(){root.activate()}}
  Island.FeedbackButton {
    anchors.fill:parent;focusable:true
    tooltipText:root.tooltip
    horizontalPadding:0;verticalPadding:0
    onClicked:root.detailsRequested()
  }
  GridLayout {
    id:content
    anchors.centerIn:parent;width:parent.width
    columns:root.presentation.vertical ? 1 : 2
    rowSpacing:Style.space(2);columnSpacing:Style.space(4)
    Island.WeatherScene {
      Layout.alignment:Qt.AlignCenter
      Layout.preferredWidth:Style.space(18);Layout.preferredHeight:Style.space(18)
      condition:root.current ? Weather.kind(root.current.code) : 2
      isDay:root.current ? root.current.isDay : true
      animated:false;opacity:root.current ? 1 : 0.35
    }
    Island.PlainText {
      objectName:"weatherIndicatorTemperature"
      Layout.alignment:Qt.AlignCenter
      Layout.maximumWidth:root.presentation.vertical ? root.presentation.barSize-Style.space(4) : Infinity
      text:root.temperatureText+(root.stale ? " ·" : "")
      typeRole:"bar";color:Island.Design.barText
      font.family:root.presentation.bar ? root.presentation.bar.fontFamily : Style.font.family
    }
  }
}
