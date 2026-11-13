pragma Singleton
import QtQuick
import ".." as Island

// Settings writes go through ModuleView.settingRequested, never this singleton.
QtObject {
  function get(key) { return Island.Preferences.get(key) }
}
