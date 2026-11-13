import QtQuick
import "../.." as Island
Island.ModulePage {
  id:root
  available:!!backend && backend.allowed
  implicitHeight:content.implicitHeight
  function cancelEditing(){content.cancelEditing()}
  function enter(){if(backend) backend.activate()}
  Island.WeatherView {
    id:content;objectName:"islandWeather";anchors.fill:parent
    weather:root.backend;strings:root.presentation.strings
    externalFeedback:root.presentation.feedback;showBack:false
    active:root.presentation.active;radialBraille:root.presentation.radialBraille
    onTemperatureUnitRequested:value=>root.settingRequested("weatherTemperatureUnit",value)
  }
}
