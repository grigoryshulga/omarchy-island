import QtQuick
import "../.." as Island
Island.WeatherService {
  allowed:Island.Preferences.get("weatherEnabled")
  unitOverride:String(Island.Preferences.values.weatherUnit || "")
  temperatureOverride:String(Island.Preferences.values.weatherTemperatureUnit || "")
  refreshOverride:Number(Island.Preferences.values.weatherRefreshMinutes || 0)
}
