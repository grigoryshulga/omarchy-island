import QtQuick

// Surfaces group content by fill and spacing, never by decorative outlines.
Rectangle {
  property bool raised: false
  readonly property bool islandSpotlightSurface: true
  color: raised ? Design.raised : Design.surface
  radius: Design.cardRadius
  border.width: 0
}
