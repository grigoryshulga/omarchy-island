import QtQuick
import "../../sdk" 1.0 as UI

// Shared across monitors. Views never construct this object themselves.
Item {
  id: root
  property bool allowed: UI.Settings.get("exampleEnabled")
  property int count: 0
  function increment() { if (allowed) count++ }
  // Add injectable paths, transport, execute(argv) and clock here when needed.
  // Stop timers/processes/subscriptions on disable and release them on destruction.
}
