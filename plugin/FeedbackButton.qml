// Adapted from Omarchy Ui.Button; see THIRD_PARTY.md.
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BorderSurface {
  id: root

  property var feedback: null
  property string variant: "quiet"
  property bool compact: false
  property string text: ""
  property string iconText: ""
  property string tooltipText: ""

  property bool selected: false
  property bool active: false
  property bool hasCursor: false
  property bool focusable: false
  property bool bordered: false

  property color foreground: variant==="primary" ? Design.selectedText : Design.text
  property color background: variant==="primary" ? Design.selection : variant==="soft" ? Design.raised : "transparent"
  property color accent: Design.accent

  property string fontFamily: Design.fontFamily
  property real fontSize: Design.type.label
  property int fontWeight: Font.Medium
  property real iconSize: Style.font.icon
  property real iconRotation: 0
  property bool iconSpinning: false
  property real horizontalPadding: Design.gap.medium
  property real verticalPadding: compact ? Design.gap.tight : Design.gap.small
  property bool leftAlign: false

  leftPadding: horizontalPadding
  rightPadding: horizontalPadding
  topPadding: verticalPadding
  bottomPadding: verticalPadding

  property color tooltipBackground: Commons.Color.tooltip.background
  property color tooltipForeground: Commons.Color.tooltip.text
  property color tooltipBorder: Commons.Color.tooltip.border

  signal clicked()
  signal rightClicked()
  signal hovered(bool isHovered)

  opacity: enabled ? 1 : Design.disabledOpacity
  Accessible.name: text || tooltipText
  Accessible.role: Accessible.Button
  Connections {target:root;function onClicked() {if(root.feedback) root.feedback.pulseFrom(root)}}
  activeFocusOnTab: focusable
  Keys.onReturnPressed: if (focusable) root.clicked()
  Keys.onEnterPressed: if (focusable) root.clicked()
  Keys.onSpacePressed: if (focusable) root.clicked()

  // Reserve focus width in every state so hover and focus never relayout siblings.
  implicitWidth: _contentNaturalWidth + horizontalPadding * 2 + _reservedBorderLeft + _reservedBorderRight
  implicitHeight: Math.max(compact ? Design.compactControlHeight : Design.controlHeight, row.implicitHeight + verticalPadding * 2 + _reservedBorderTop + _reservedBorderBottom)
  radius: Design.controlRadius

  readonly property bool hot: mouseArea.containsMouse || hasCursor
  readonly property bool _showFocusRing: focusable && activeFocus
  readonly property color _selectedColor: Design.selectedText
  readonly property var _tooltipBorderSpec: Border.localOrSurfaceSpec("tooltip", "border", root.tooltipBorder, Commons.Color.tooltip.border, Math.max(1, Style.normalBorderWidth))
  readonly property var _focusBorderSpec: Border.flat(Design.focusRing,2)
  readonly property var _hoverBorderSpec: Border.none()
  readonly property var _selectedBorderSpec: Border.flat(Design.accent,1)
  readonly property var _normalBorderSpec: Border.flat(Design.fieldBorder,1)
  readonly property real _reservedBorderTop: Math.max(
    focusable ? Border.top(_focusBorderSpec) : 0,
    Border.top(_hoverBorderSpec),
    Border.top(_selectedBorderSpec),
    bordered ? Border.top(_normalBorderSpec) : 0)
  readonly property real _reservedBorderRight: Math.max(
    focusable ? Border.right(_focusBorderSpec) : 0,
    Border.right(_hoverBorderSpec),
    Border.right(_selectedBorderSpec),
    bordered ? Border.right(_normalBorderSpec) : 0)
  readonly property real _reservedBorderBottom: Math.max(
    focusable ? Border.bottom(_focusBorderSpec) : 0,
    Border.bottom(_hoverBorderSpec),
    Border.bottom(_selectedBorderSpec),
    bordered ? Border.bottom(_normalBorderSpec) : 0)
  readonly property real _reservedBorderLeft: Math.max(
    focusable ? Border.left(_focusBorderSpec) : 0,
    Border.left(_hoverBorderSpec),
    Border.left(_selectedBorderSpec),
    bordered ? Border.left(_normalBorderSpec) : 0)
  readonly property real _reservedContentLeftInset: _reservedBorderLeft + leftPadding
  readonly property real _iconRoom: root.iconText !== "" ? iconGlyph.implicitWidth + (root.text !== "" ? row.spacing : 0) : 0
  readonly property real _contentNaturalWidth: _iconRoom + (root.text !== "" ? label.implicitWidth : 0)
  readonly property real _labelRoom: width - horizontalPadding - _reservedBorderLeft - _reservedBorderRight - _iconRoom
  readonly property var _borderSpec: _showFocusRing ? _focusBorderSpec
    : hot                      ? _hoverBorderSpec
    : selected                 ? (bordered ? _selectedBorderSpec : Border.none())
    : bordered                 ? _normalBorderSpec
    : Border.none()

  color: mouseArea.pressed ? Design.pressed
    : _showFocusRing       ? Design.hover
    : hot                  ? Design.hover
    : selected             ? Design.selection
    : active               ? Design.selection
    : background

  borderSpec: _borderSpec

  Behavior on color { ColorAnimation { duration: Design.feedbackDuration } }

  scale: 1
  Behavior on scale {
    NumberAnimation {
      duration: Design.transitionDuration
      easing.type: Easing.Bezier
      easing.bezierCurve: Style.easeOut
    }
  }

  ToolTip {
    visible: root.tooltipText !== "" && mouseArea.containsMouse
    text: root.tooltipText
    delay: 400
    padding: 0
    background: BorderSurface {
      color: root.tooltipBackground
      borderSpec: root._tooltipBorderSpec
      radius: 0
    }
    contentItem: Text {
      textFormat: Text.PlainText
      text: root.tooltipText
      color: root.tooltipForeground
      font.family: root.fontFamily
      font.pixelSize: Design.type.caption
      leftPadding: Border.left(root._tooltipBorderSpec) + Style.spacing.controlPaddingX
      rightPadding: Border.right(root._tooltipBorderSpec) + Style.spacing.controlPaddingX
      topPadding: Border.top(root._tooltipBorderSpec) + Style.spacing.controlPaddingY
      bottomPadding: Border.bottom(root._tooltipBorderSpec) + Style.spacing.controlPaddingY
    }
  }

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: root.leftAlign ? parent.left : undefined
    anchors.leftMargin: root.leftAlign ? root._reservedContentLeftInset : 0
    anchors.horizontalCenter: root.leftAlign ? undefined : parent.horizontalCenter
    spacing: Style.spacing.controlGap

    Text {
      id: iconGlyph
      textFormat: Text.PlainText
      visible: root.iconText !== ""
      text: root.iconText
      color: root.selected ? root._selectedColor : root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.iconSize
      rotation: root.iconSpinning ? 0 : root.iconRotation
      transformOrigin: Item.Center
      anchors.verticalCenter: parent.verticalCenter

      RotationAnimation on rotation {
        from: 0
        to: 360
        duration: Design.spinnerDuration
        loops: Animation.Infinite
        running: root.iconSpinning && root.visible && !Preferences.reduceMotion
      }
    }

    Text {
      id: label
      textFormat: Text.PlainText
      visible: root.text !== ""
      text: root.text
      color: root.selected ? root._selectedColor : root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      font.weight: root.selected ? Font.DemiBold : root.fontWeight
      width: Math.max(0, Math.min(implicitWidth, root._labelRoom))
      fontSizeMode: Text.HorizontalFit
      minimumPixelSize: Math.round(root.fontSize * 0.75)
      elide: Text.ElideRight
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    scale: 1 / root.scale
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (root.focusable) root.forceActiveFocus()
      if (mouse.button === Qt.RightButton) root.rightClicked()
      else root.clicked()
    }
  }

  HoverHandler {
    onHoveredChanged: root.hovered(hovered)
  }
}
