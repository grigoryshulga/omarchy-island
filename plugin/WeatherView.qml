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
  signal backRequested()
  signal temperatureUnitRequested(string value)
  implicitHeight: body.implicitHeight
  onActiveChanged: if(!active) cancelEditing()
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
  HoverHandler { id: hover }
  BrailleFeedback { id: weatherFeedback; surface: root; effect: glow; hover: hover }
  BrailleSpotlight { id: glow; objectName: "weatherSpotlight"; anchors.fill: parent; active: !root.externalFeedback && hover.hovered; pointer: hover.point.position; adaptive: root.radialBraille }
  ColumnLayout {
    id: body
    width: parent.width
    spacing: Style.space(10)
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(4)
      FeedbackButton { objectName: "weatherBack"; visible: root.showBack; feedback: root.feedback; iconText: Commons.I18n.rightToLeft ? "󰁔" : "󰁍"; tooltipText: root.strings.t("calendar.back"); radius: Math.min(Style.cornerRadius,Style.space(6)); horizontalPadding: Style.space(5); focusable: true; onClicked: root.backRequested() }
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
          fontSize: Style.font.title
          radius: Math.min(Style.cornerRadius,Style.space(6))
          leftAlign: true
          focusable: true
          tooltipText: root.strings.t("weather.changeCity")
          onClicked: root.startEditing()
        }
        TextField {
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
        color: Commons.Color.muted
        font.pixelSize: Style.font.caption
      }
      FeedbackButton { objectName: "weatherRefresh"; feedback: root.feedback; iconText: "󰑐"; tooltipText: root.strings.t("weather.refresh"); radius: Math.min(Style.cornerRadius,Style.space(6)); horizontalPadding: Style.space(5); focusable: true; enabled: root.weather!==null && !root.weather.loading; onClicked: root.weather.refresh() }
    }
    ColumnLayout {
      id: suggestions
      Layout.fillWidth: true
      visible: root.editing && root.weather && (root.weather.suggestions.length>0 || root.weather.searching)
      spacing: Style.space(6)
      Repeater {
        model: root.weather ? root.weather.suggestions : []
        FeedbackButton {
          required property var modelData
          feedback: root.feedback
          Layout.fillWidth: true
          text: modelData.name+" · "+modelData.description
          leftAlign: true
          fontSize: Style.font.bodySmall
          radius: Math.min(Style.cornerRadius,Style.space(6))
          focusable: true
          onClicked: {var place=modelData;city.text=place.name;searchDelay.stop();root.draftPlace=place;city.forceActiveFocus()}
        }
      }
      PlainText { visible: root.weather!==null && root.weather.searching; text: root.strings.t("weather.searching"); color: Commons.Color.muted; font.pixelSize: Style.font.caption }
    }
    Item {
      Layout.fillWidth: true
      implicitHeight: Style.space(184)
      WeatherScene {
        objectName: "weatherHeroScene"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Math.min(parent.width,Style.space(240))
        height: Style.space(168)
        condition: root.condition<0 ? 2 : root.condition
        isDay: root.current ? root.current.isDay : true
        animated: root.active && root.current!==null
        opacity: root.current ? 1 : 0.25
      }
      RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        visible: root.current!==null
        spacing: 0
        PlainText {
          objectName: "weatherTemperature"
          text: Commons.I18n.formatNumber(Model.temperature(root.current ? root.current.temperature : null,root.temperatureUnit))
          font.pixelSize: Style.space(42)
          font.bold: true
        }
        BorderSurface {
          id: unitButton
          objectName: "weatherUnit"
          readonly property string text: Model.unitSymbol(root.temperatureUnit)
          readonly property bool hot: unitMouse.containsMouse
          implicitWidth: unitLabel.implicitWidth+Style.space(4)
          implicitHeight: unitLabel.implicitHeight
          color: "transparent"
          borderSpec: activeFocus ? Border.controlSpec("focus",Commons.Color.foreground,Commons.Color.accent) : Border.none()
          radius: Math.min(Style.cornerRadius,Style.space(6))
          activeFocusOnTab: true
          function activate() {root.feedback.pulseFrom(unitButton);root.cycleTemperatureUnit()}
          PlainText {
            id: unitLabel
            anchors.centerIn: parent
            text: unitButton.text
            font.pixelSize: Style.space(42)
            color: unitButton.hot || unitButton.activeFocus ? Commons.Color.accent : Commons.Color.foreground
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
            padding: Style.space(6)
            background: BorderSurface {color:Commons.Color.tooltip.background;borderSpec:Border.surfaceSpec("tooltip","border",Commons.Color.tooltip.border,Math.max(1,Style.normalBorderWidth));radius:0}
            contentItem: PlainText {text:root.strings.t("weather.changeUnit");color:Commons.Color.tooltip.text;font.pixelSize:Style.font.bodySmall}
          }
          Keys.onReturnPressed: activate()
          Keys.onEnterPressed: activate()
          Keys.onSpacePressed: activate()
        }
      }
      PlainText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width
        visible: root.current===null
        horizontalAlignment: Text.AlignHCenter
        text: root.strings.t(root.weather && root.weather.loading ? "weather.loading" : "weather.noData")
        font.pixelSize: Style.font.bodySmall
        color: Commons.Color.muted
      }
    }
    RowLayout {
      Layout.fillWidth: true
      visible: root.current!==null
      uniformCellSizes: true
      spacing: Style.space(8)
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
            spacing: Style.space(4)
            PlainText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData.label; color: Commons.Color.muted; font.pixelSize: Style.font.caption }
            PlainText { objectName: "weatherStat-"+statItem.index; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData.value; font.pixelSize: Style.font.body }
          }
        }
      }
    }
    PanelSeparator { Layout.fillWidth: true; visible: root.report!==null }
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(4)
      uniformCellSizes: true
      visible: root.report!==null
      Repeater {
        objectName: "weatherForecast"
        model: root.report ? root.report.days.slice(1,8) : []
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
            spacing: Style.space(3)
            PlainText { Layout.alignment: Qt.AlignHCenter; text: new Date(modelData.date+"T12:00:00").toLocaleDateString(Qt.locale(Commons.I18n.formatLocale),"ddd"); color: Commons.Color.muted; font.pixelSize: Style.font.caption }
            WeatherScene { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: Math.min(forecastDay.width,Style.space(56)); Layout.preferredHeight: Style.space(44); condition: Model.kind(modelData.code)<0 ? 2 : Model.kind(modelData.code); animated: false }
            PlainText { objectName: "weatherDayHigh"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.temp(modelData.max); font.pixelSize: Style.font.bodySmall }
            PlainText { objectName: "weatherDayLow"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.temp(modelData.min); color: Commons.Color.muted; font.pixelSize: Style.font.caption }
          }
        }
      }
    }
    PlainText {
      Layout.fillWidth: true
      visible: root.weather!==null && (root.weather.error!=="" || root.weather.stale)
      text: root.strings.t(root.report ? "weather.stale" : "weather.failure")
      color: Commons.Color.muted
      wrapMode: Text.Wrap
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
    }
  }
  Timer { id: searchDelay; interval: 300; onTriggered: if(root.weather && root.editing) root.weather.search(city.text) }
}
