import QtQuick
import "../.." as Island
Island.ModulePage {
  id:root
  available:!!backend && backend.allowed
  implicitHeight:content.implicitHeight
  function cancelEditing(){content.cancelEditing()}
  function back(){if(content.editing) {content.cancelEditing();return true};return false}
  function enter(){if(backend) backend.activate()}
  Island.WeatherView {
    id:content;objectName:"islandWeather";anchors.fill:parent
    weather:root.backend;strings:root.presentation.strings
    externalFeedback:root.presentation.feedback;showBack:true
    active:root.presentation.active;radialBraille:root.presentation.radialBraille
    onBackRequested:root.presentation.goBack()
    onTemperatureUnitRequested:value=>root.settingRequested("weatherTemperatureUnit",value)
  }
}
