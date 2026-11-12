import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "WeatherModel.js" as Model

Item {
  id: root
  required property var strings
  property var weather: null
  property bool active: true
  property bool radialBraille: true
  property var externalFeedback: null
  readonly property var feedback: externalFeedback || weatherFeedback
  property bool showBack: true
  property bool editing: false
  property var draftPlace: null
  property bool draftAuto: false
  readonly property var report: weather ? weather.report : null
  readonly property var current: report ? report.current : null
  readonly property bool imperial: weather ? weather.useImperial : false
  readonly property string temperatureUnit: weather ? weather.temperatureUnit : "celsius"
  readonly property int condition: current ? Model.kind(current.code) : -1
  readonly property var forecast: Model.temperatureRanges(report ? report.days.slice(1,8) : [])
  readonly property var solar: Model.solarEvents(clockNow,report)
  LayoutMirroring.enabled: Commons.I18n.rightToLeft
  LayoutMirroring.childrenInherit: true
  TextMetrics {
    id: forecastMetrics
    font.family: Design.fontFamily
    font.pixelSize: Design.type.caption
    text: root.temp(-100)
  }
  signal backRequested()
  signal temperatureUnitRequested(string value)
  implicitHeight: body.implicitHeight
  onActiveChanged: { if(!active) cancelEditing(); else clockNow=Date.now() }
  function cancelEditing() {
    editing=false;searchDelay.stop();draftPlace=null;draftAuto=false
    if(weather) weather.cancelSearch()
    city.text=""
  }
  function startEditing() {
    cancelEditing();editing=true
    Qt.callLater(function(){city.forceActiveFocus()})
  }
  function commitCity() {
    if(!weather) return
    if(draftAuto) weather.autoLocate()
    else {
      var place=draftPlace || weather.suggestions[0]
      if(!place) return
      weather.choose(place)
    }
    cancelEditing()
  }
  function inside(item,position) {
    var at=item.mapFromItem(root,position.x,position.y)
    return item.visible && at.x>=0 && at.y>=0 && at.x<=item.width && at.y<=item.height
  }
  TapHandler {
    acceptedButtons: Qt.AllButtons
    onPressedChanged: if(pressed && root.editing && !root.inside(locationSlot,point.position) && !root.inside(suggestions,point.position) && !root.inside(autoButton,point.position)) root.cancelEditing()
  }
  function temp(value) { var n=Model.temperature(value,temperatureUnit); return n===null ? "—" : Commons.I18n.formatNumber(n)+(temperatureUnit==="kelvin" ? " K" : "°") }
  function cycleTemperatureUnit() {temperatureUnitRequested(Model.nextTemperatureUnit(temperatureUnit))}
  function stat(value,suffix) { return value===null || value===undefined ? "—" : Commons.I18n.formatNumber(Math.round(value))+suffix }
  function solarLabel(key,value) { return strings.t(key).arg(value ? value.toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),Locale.ShortFormat) : "—") }
  property double clockNow: Date.now()
  Timer {
    interval: 30000
    running: root.active && root.visible
    repeat: true
    onTriggered: root.clockNow=Date.now()
  }
  onReportChanged: clockNow=Date.now()
  onVisibleChanged: if(visible) clockNow=Date.now()
  HoverHandler { id: hover }
  BrailleFeedback { id: weatherFeedback; surface: root; effect: glow; hover: hover }
  BrailleSpotlight { id: glow; surfaceRoot: root; objectName: "weatherSpotlight"; anchors.fill: parent; active: !root.externalFeedback && hover.hovered; pointer: hover.point.position; adaptive: root.radialBraille }
  ColumnLayout {
    id: body
    width: parent.width
    height:Math.max(implicitHeight,root.height)
    spacing:Design.gap.section
    RowLayout {
      Layout.fillWidth: true
      spacing:Design.gap.tight
      FeedbackButton { objectName: "weatherBack"; visible: root.showBack; feedback: root.feedback; iconText: Commons.I18n.rightToLeft ? "󰁔" : "󰁍"; tooltipText: root.strings.t("calendar.back"); radius: Design.controlRadius; horizontalPadding:Design.gap.small; focusable: true; onClicked: root.backRequested() }
      Item {
        id: locationSlot
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitHeight: Math.max(locationButton.implicitHeight,city.implicitHeight)
        FeedbackButton {
          id: locationButton
          objectName: "weatherLocation"
          anchors.fill: parent
          visible: !root.editing
          feedback: root.feedback
          text: root.report && root.report.location ? root.report.location : root.strings.t("weather.title")
          fontSize: Design.type.section
          fontWeight: Design.weight("section")
          radius: Design.controlRadius
          leftAlign: true
          focusable: true
          tooltipText: root.strings.t("weather.changeCity")
          onClicked: root.startEditing()
        }
        DesignTextField {
          id: city
          objectName: "weatherCityInput"
          anchors.fill: parent
          visible: root.editing
          placeholderText: root.strings.t("weather.searchCity")
          onTextChanged: if(root.editing) {root.draftPlace=null;root.draftAuto=false;root.weather.cancelSearch();searchDelay.restart()}
          Keys.onReturnPressed: root.commitCity()
          Keys.onEnterPressed: root.commitCity()
          Keys.onEscapePressed: event => {root.cancelEditing();event.accepted=true}
        }
      }
      ActionButton {
        id: autoButton
        objectName: "weatherAuto"
        visible: root.editing
        feedback: root.feedback
        text: root.strings.t("weather.auto")
        onClicked: {city.text=root.strings.t("weather.auto");searchDelay.stop();root.draftAuto=true;city.forceActiveFocus()}
      }
      PlainText {
        objectName: "weatherUpdated"
        Layout.maximumWidth: root.width*0.45
        visible: !root.editing && text!==""
        text: root.weather && root.weather.loading ? root.strings.t("weather.loading") : root.report ? root.strings.t("weather.updated").arg(new Date(root.report.fetchedAt*1000).toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH:mm")) : ""
        color: Design.secondaryText
        typeRole:"caption"
      }
      FeedbackButton { objectName: "weatherRefresh"; feedback: root.feedback; iconText: "󰑐"; tooltipText: root.strings.t("weather.refresh"); radius: Design.controlRadius; horizontalPadding:Design.gap.small; focusable: true; enabled: root.weather!==null && !root.weather.loading; onClicked: root.weather.refresh() }
    }
    ColumnLayout {
      id: suggestions
      Layout.fillWidth: true
      visible: root.editing && root.weather && (root.weather.suggestions.length>0 || root.weather.searching)
      spacing:Design.gap.small
      Repeater {
        model: root.weather ? root.weather.suggestions : []
        FeedbackButton {
          required property var modelData
          feedback: root.feedback
          Layout.fillWidth: true
          text: modelData.name+" · "+modelData.description
          leftAlign: true
          fontSize: Design.type.label
          radius: Design.controlRadius
          focusable: true
          onClicked: {var place=modelData;city.text=place.name;searchDelay.stop();root.draftPlace=place;city.forceActiveFocus()}
        }
      }
      PlainText { visible: root.weather!==null && root.weather.searching; text: root.strings.t("weather.searching"); color: Design.secondaryText; typeRole:"caption" }
    }
    Item {
      id: hero
      objectName: "weatherHero"
      Layout.fillWidth: true
      Layout.fillHeight: true
      implicitHeight: Math.max(Style.space(152),summary.implicitHeight)
      ColumnLayout {
        id: summary
        objectName: "weatherSummary"
        width: Math.max(temperatureRow.implicitWidth,(hero.width-Design.gap.large)/2)
        height: implicitHeight
        x: Commons.I18n.rightToLeft ? hero.width-width : 0
        y: (hero.height-height)/2
        spacing: Design.gap.small
        PlainText {
          Layout.fillWidth: true
          text: root.strings.t("weather.now")
          typeRole: "caption"
          color: Design.secondaryText
          horizontalAlignment: Text.AlignLeft
          visible: root.current!==null
        }
        RowLayout {
          id: temperatureRow
          visible: root.current!==null
          spacing: 0
          // Keep the number and its unit together in both text directions.
          LayoutMirroring.enabled: false
          LayoutMirroring.childrenInherit: true
          PlainText {
            objectName: "weatherTemperature"
            text: Commons.I18n.formatNumber(Model.temperature(root.current ? root.current.temperature : null,root.temperatureUnit))
            typeRole: "hero"
          }
          BorderSurface {
            id: unitButton
            objectName: "weatherUnit"
            readonly property string text: Model.unitSymbol(root.temperatureUnit)
            readonly property bool hot: unitMouse.containsMouse
            implicitWidth: unitLabel.implicitWidth+Style.space(4)
            implicitHeight: unitLabel.implicitHeight
            color: "transparent"
            borderSpec: activeFocus ? Border.controlSpec("focus",Design.text,Design.accent) : Border.none()
            radius: Design.controlRadius
            activeFocusOnTab: true
            Layout.alignment: Qt.AlignTop
            function activate() {root.feedback.pulseFrom(unitButton);root.cycleTemperatureUnit()}
            PlainText {
              id: unitLabel
              anchors.centerIn: parent
              text: unitButton.text
              typeRole: "page"
              color: unitButton.hot || unitButton.activeFocus ? Design.accent : Design.text
            }
            MouseArea {
              id: unitMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {unitButton.forceActiveFocus();root.feedback.pulseFrom(unitButton)}
              onDoubleClicked: unitButton.activate()
            }
            Controls.ToolTip {
              visible: unitMouse.containsMouse
              delay: 400
              text: root.strings.t("weather.changeUnit")
              padding:Design.gap.small
              background: BorderSurface {color:Commons.Color.tooltip.background;borderSpec:Border.surfaceSpec("tooltip","border",Commons.Color.tooltip.border,Math.max(1,Style.normalBorderWidth));radius:0}
              contentItem: PlainText {text:root.strings.t("weather.changeUnit");color:Commons.Color.tooltip.text;typeRole:"caption"}
            }
            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()
          }
        }
        PlainText {
          objectName: "weatherCondition"
          Layout.fillWidth: true
          text: root.current ? root.strings.t(root.condition<0 ? "weather.unknown" : "weather.condition."+root.condition)
            : root.strings.t(root.weather && root.weather.loading ? "weather.loading" : "weather.noData")
          typeRole: root.current ? "body" : "caption"
          color: root.current ? Design.text : Design.secondaryText
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignLeft
        }
      }
      WeatherScene {
        objectName: "weatherHeroScene"
        width: Math.max(0,hero.width-summary.width-Design.gap.large)
        height: Style.space(152)
        x: Commons.I18n.rightToLeft ? 0 : summary.width+Design.gap.large
        y: (hero.height-height)/2
        condition: root.condition<0 ? 2 : root.condition
        isDay: root.current ? root.current.isDay : true
        animated: root.active && root.visible && root.current!==null
        opacity: root.current ? 1 : 0.25
      }
    }
    RowLayout {
      Layout.fillWidth: true
      visible: root.current!==null
      uniformCellSizes: true
      spacing:Design.gap.small
      Repeater {
        model: [
          {label:root.strings.t("weather.feels"),value:root.temp(root.current ? root.current.feels : null)},
          {label:root.strings.t("weather.wind"),value:root.stat(root.current && root.current.wind!==null ? root.current.wind*(root.imperial ? 0.621371 : 1) : null,root.strings.t(root.imperial ? "weather.mph" : "weather.kmh"))},
          {label:root.strings.t("weather.humidity"),value:root.stat(root.current ? root.current.humidity : null,"%")}
        ]
        Item {
          id: statItem
          required property var modelData
          required property int index
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          implicitHeight: statColumn.implicitHeight
          ColumnLayout {
            id: statColumn
            width: parent.width
            spacing:Design.gap.tight
            PlainText { Layout.fillWidth: true; horizontalAlignment: Text.AlignLeft; wrapMode: Text.Wrap; text: modelData.label; color: Design.secondaryText; typeRole:"caption" }
            PlainText { objectName: "weatherStat-"+statItem.index; Layout.fillWidth: true; horizontalAlignment: Text.AlignLeft; wrapMode: Text.Wrap; text: modelData.value; typeRole:"body" }
          }
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      visible: root.forecast.length>0
      spacing: Design.gap.medium
      PlainText {
        Layout.fillWidth: true
        text: root.strings.t("weather.forecast")
        typeRole: "caption"
        color: Design.secondaryText
        horizontalAlignment: Text.AlignLeft
      }
      GridLayout {
        objectName: "weatherForecastGrid"
        Layout.fillWidth: true
        columns: Math.min(7,Math.max(1,Math.floor((width+columnSpacing)/(forecastMetrics.advanceWidth+columnSpacing))))
        columnSpacing: Design.gap.tight
        rowSpacing: Design.gap.medium
        uniformCellWidths: true
        Repeater {
          objectName: "weatherForecast"
          model: root.forecast
          Item {
            id: forecastDay
            required property var modelData
            required property int index
            objectName: "weatherDay-"+index
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            implicitHeight: dayColumn.implicitHeight
            ColumnLayout {
              id: dayColumn
              width: parent.width
              spacing: Design.gap.tight
              PlainText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: new Date(modelData.date+"T12:00:00").toLocaleDateString(Qt.locale(Commons.I18n.formatLocale),"ddd"); color: Design.secondaryText; typeRole: "caption" }
              WeatherScene { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: Math.min(forecastDay.width,Style.space(48)); Layout.preferredHeight: Style.space(32); condition: Model.kind(modelData.code)<0 ? 2 : Model.kind(modelData.code); animated: false }
              PlainText { objectName: "weatherDayHigh"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.temp(modelData.max); typeRole: "caption" }
              Rectangle {
                id: rangeTrack
                objectName: "weatherRangeTrack"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Style.space(4)
                Layout.preferredHeight: Style.space(40)
                color: Design.raised
                radius: Math.min(Design.controlRadius,width/2)
                Rectangle {
                  objectName: "weatherRange"
                  readonly property real markerHeight: Math.min(parent.height,Style.space(2))
                  width: parent.width
                  y: modelData.rangeTop*(parent.height-markerHeight)
                  height: markerHeight+modelData.rangeHeight*(parent.height-markerHeight)
                  radius: parent.radius
                  color: Design.accent
                }
              }
              PlainText { objectName: "weatherDayLow"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.temp(modelData.min); color: Design.secondaryText; typeRole: "caption" }
            }
          }
        }
      }
    }
    RowLayout {
      Layout.fillWidth: true
      visible: root.current!==null
      spacing: Design.gap.medium
      PlainText {
        objectName: "weatherSunrise"
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        text: root.solarLabel("weather.sunrise",root.solar.sunrise)
        typeRole: "caption"
        color: Design.secondaryText
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignLeft
      }
      PlainText {
        objectName: "weatherSunset"
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        text: root.solarLabel("weather.sunset",root.solar.sunset)
        typeRole: "caption"
        color: Design.secondaryText
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignRight
      }
    }
    PlainText {
      Layout.fillWidth: true
      visible: root.weather!==null && (root.weather.error!=="" || root.weather.stale)
      text: root.strings.t(root.report ? "weather.stale" : "weather.failure")
      color: Design.secondaryText
      wrapMode: Text.Wrap
      typeRole:"caption"
      horizontalAlignment: Text.AlignHCenter
    }
  }
  Timer { id: searchDelay; interval: 300; onTriggered: if(root.weather && root.editing) root.weather.search(city.text) }
}
