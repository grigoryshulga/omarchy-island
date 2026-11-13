pragma Singleton
import QtQuick
import ".." as Island

QtObject {
  readonly property bool reduceMotion: Island.Preferences.reduceMotion
  function duration(milliseconds) { return Island.Preferences.duration(milliseconds) }
}
