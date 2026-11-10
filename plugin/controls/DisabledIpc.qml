import QtQuick

// Adapted native panels must not claim another plugin's process-global routes.
QtObject {
  property string target: ""
  property bool enabled: false
}
