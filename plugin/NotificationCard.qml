import QtQuick
import Quickshell
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "Security.js" as Security

Rectangle {
  id: root
  readonly property bool islandSpotlightSurface: !grouped
  objectName: "notification-" + row.key
  required property var row
  required property var service
  required property var strings
  property bool expanded: false
  property bool islandNavigationContainer:true
  activeFocusOnTab:expanded
  KeyboardNavigation {id:focusWatch;scope:root}
  readonly property bool keyboardFocused:focusWatch.contains(root,focusWatch.focused)
  Keys.onReturnPressed:{root.feedback.pulseFrom(root);root.service.activate(root.row)}
  Keys.onEnterPressed:{root.feedback.pulseFrom(root);root.service.activate(root.row)}
  Keys.onSpacePressed:{root.feedback.pulseFrom(root);root.service.activate(root.row)}
  property bool radialBraille: true
  property bool grouped: false
  property bool compact: false
  property bool separated: false
  property bool individualDismiss: true
  property bool showTimestamp: true
  property real dismissShown: hover.hovered || keyboardFocused ? 1 : 0
  Behavior on dismissShown {NumberAnimation {duration:Preferences.duration(150);easing.type:Easing.OutCubic}}
  readonly property var members: row.members || [row]
  readonly property var senderActions: Model.notificationActions(row,function(member) { return service.actions(member) })
  readonly property var codeActions: {
    var found = []
    members.forEach(function(member) {
      String(member.codes || "").split(" ").filter(function(code) { return code !== "" }).forEach(function(code) {
        if (!found.some(function(item) { return item.code === code })) found.push({code:code,row:member})
      })
    })
    return found
  }
  readonly property var linkActions: {
    var found = []
    members.forEach(function(member) {
      if (member.link && !found.some(function(item) { return item.link === member.link })) found.push({link:member.link})
    })
    return found
  }
  // Commands refer to one concrete item (e.g. a screenshot path). A merged
  // card opens the newest item; never duplicate buttons or launch every file.
  readonly property var execActions: (Security.parseExecActions(members[0].execActions) || []).map(function(action,index) {
    return {label:action.label,row:members[0],index:index}
  })
  // Action definitions change much less often than notification bodies. Bind
  // delegates to those definitions, then resolve the latest target on click.
  readonly property string codeSchema: JSON.stringify(codeActions.map(function(action){return action.code}))
  readonly property string linkSchema: JSON.stringify(linkActions.map(function(action){return action.link}))
  readonly property string senderSchema: JSON.stringify(senderActions.filter(function(action){return action.id!=="default"}).map(function(action){return {id:action.id,text:action.text}}))
  readonly property string execSchema: JSON.stringify(execActions.map(function(action){return {label:action.label,index:action.index}}))
  function dismiss() {
    var backend = service, keys = members.map(function(member) { return member.key })
    keys.forEach(function(key) { backend.remove(key) })
  }
  function invokeAction(action) {
    var backend = service, id = action.id
    action.targets.slice().forEach(function(member) { backend.invoke(member,id) })
  }
  readonly property bool hasActions: !grouped || linkActions.length>0 || codeActions.length>0 || senderActions.some(function(action){return action.id!=="default"}) || execActions.length>0
  property var feedback: brailleFeedback
  property string copied: ""
  signal expandRequested()
  opacity: 0
  Component.onCompleted: opacity = 1
  Behavior on opacity { NumberAnimation { duration: Preferences.duration(180); easing.type: Easing.OutCubic } }
  color: grouped ? "transparent" : Design.surface
  border.width: 0
  radius: Design.cardRadius
  implicitHeight: content.implicitHeight + (grouped ? 0 : 2*Design.cardPadding) + (separated ? Design.gap.large : 0)
  BorderSurface {anchors.fill:parent;color:"transparent";radius:Design.cardRadius;borderSpec:Border.controlSpec("focus",Design.text,Design.accent);visible:root.keyboardFocused}

  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mouse => { root.feedback.pulseFrom(root,Qt.point(mouse.x,mouse.y)); root.service.activate(root.row) } }
  HoverHandler { id: hover }
  BrailleFeedback { id: brailleFeedback; surface: root; effect: glow; hover: hover }
  BrailleSpotlight { id: glow; surfaceRoot: root; objectName: "notificationSpotlight"; anchors.fill: parent; active: !root.grouped && root.feedback===brailleFeedback && hover.hovered; pointer: hover.point.position; adaptive: root.radialBraille }
  ColumnLayout {
    id: content
    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    anchors.margins: root.grouped ? 0 : Design.cardPadding
    anchors.topMargin: root.separated ? Design.gap.large : root.grouped ? 0 : Design.cardPadding
    spacing: root.compact ? Design.gap.tight : Design.gap.small
    RowLayout {
      visible: !root.grouped
      Layout.fillWidth: true
      Item {
        visible: !root.grouped
        Layout.preferredWidth: Style.space(18); Layout.preferredHeight: width
        PlainText { anchors.centerIn: parent; text: "󰂚"; color: Design.accent; visible: appIcon.status !== Image.Ready }
        Image { id: appIcon; anchors.fill: parent; source: root.row.appIcon ? Quickshell.iconPath(root.row.appIcon,true) : ""; asynchronous: true; fillMode: Image.PreserveAspectFit }
      }
      PlainText { visible: !root.grouped; Layout.fillWidth: true; text: Model.source(root.row); color: Design.accent; typeRole:"caption" }
      Item { visible: root.grouped; Layout.fillWidth: true }
      PlainText { text: new Date(root.row.ts*1000).toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH:mm"); color: Design.secondaryText; typeRole:"caption" }
      FeedbackButton { feedback: root.feedback; radius: Math.min(Style.cornerRadius,Style.space(4)); visible: root.expanded; opacity: hover.hovered || root.keyboardFocused ? 1 : 0; enabled: opacity > 0; iconText: "󰅖"; tooltipText: root.strings.t("delete"); horizontalPadding:Design.gap.tight; verticalPadding: 0; implicitHeight:Design.inlineControlHeight; focusable: true; onClicked: root.dismiss() }
    }
    RowLayout {
      Layout.fillWidth: true
      PlainText { Layout.fillWidth: true; text: root.row.summary; typeRole:root.compact ? "body" : "title"; wrapMode: Text.Wrap; maximumLineCount: root.expanded ? 8 : 1; elide: Text.ElideRight }
      PlainText {objectName:"notificationTime";Layout.alignment:Qt.AlignTop;visible:root.grouped && root.showTimestamp;text:new Date(root.row.ts*1000).toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH:mm");color:Design.secondaryText;typeRole:"caption"}
      Item {
        visible:root.grouped && root.expanded && root.individualDismiss
        Layout.preferredWidth:rowDismiss.implicitWidth*root.dismissShown
        Layout.minimumWidth:0;Layout.maximumWidth:Layout.preferredWidth
        Layout.preferredHeight:rowDismiss.implicitHeight
        clip:true
      FeedbackButton { id:rowDismiss; objectName:"notificationDismiss"; feedback: root.feedback; radius: Math.min(Style.cornerRadius,Style.space(4)); visible: root.grouped && root.expanded && root.individualDismiss; opacity: hover.hovered || root.keyboardFocused ? 1 : 0; enabled: opacity > 0; iconText: "󰅖"; tooltipText: root.strings.t("delete"); horizontalPadding:Design.gap.tight; verticalPadding: 0; implicitHeight:Design.inlineControlHeight; focusable: true; onClicked: root.dismiss() }
      }
    }
    PlainText { objectName:"notificationBody"; Layout.fillWidth: true; visible: text !== ""; text: root.row.members ? root.row.body : Model.plain(root.row.body); typeRole:"caption"; color: Design.secondaryText; wrapMode: Text.Wrap; maximumLineCount: root.compact ? 1 : root.expanded ? 1000 : 2; elide: Text.ElideRight }
    Item {
      objectName:"notificationFooter"
      Layout.fillWidth: true
      property real reveal: !root.compact && (hover.hovered || root.keyboardFocused) ? 1 : 0
      implicitHeight: actions.implicitHeight
      visible: !root.compact && root.hasActions
      clip: true
      Behavior on reveal { NumberAnimation { duration: Preferences.duration(150); easing.type: Easing.OutCubic } }
      Flow {
        id: actions
        anchors.right: parent.right
        property real naturalWidth: {
          var total=0, count=0
          for(var i=0;i<children.length;i++) {
            var child=children[i]
            if(child.visible && child.implicitWidth>0) { total+=child.implicitWidth; count++ }
          }
          return total+Math.max(0,count-1)*spacing
        }
        width: Math.max(0,Math.min(parent.width,naturalWidth))
        opacity: parent.reveal
        enabled: parent.reveal>0
      spacing:Design.gap.tight
      Repeater {
        model: JSON.parse(root.codeSchema)
        ActionButton {
          feedback: root.feedback
          required property string modelData
          objectName: "copyCode-" + modelData
          text: (root.copied === modelData ? "✓ " : "󰆏 ") + modelData
          focusable: true; bordered: true
          onClicked: {var action=root.codeActions.find(function(action){return action.code===modelData});if(action) {root.service.copyCode(action.row,action.code);root.copied=action.code}}
        }
      }
      Repeater {
        model: JSON.parse(root.linkSchema)
        ActionButton {
          feedback: root.feedback
          required property string modelData
          text: root.strings.t("openLink")
          focusable: true
          onClicked: Security.openExternalUrl(modelData)
        }
      }
      Repeater {
        model: JSON.parse(root.senderSchema)
        ActionButton {
          feedback: root.feedback
          required property var modelData
          objectName: "notificationAction-" + modelData.id
          text: Model.plain(modelData.text)
          focusable: true
          onClicked: {var action=root.senderActions.find(function(action){return action.id===modelData.id && action.text===modelData.text});if(action) root.invokeAction(action)}
        }
      }
      Repeater {
        model: JSON.parse(root.execSchema)
        ActionButton {
          feedback: root.feedback
          required property var modelData
          objectName: "notificationExecAction-" + modelData.index
          text: Model.plain(modelData.label)
          focusable: true
          onClicked: {var action=root.execActions[modelData.index];if(action) root.service.execAction(action.row,action.index)}
        }
      }
      ActionButton {
        feedback: root.feedback
        objectName: "muteSource"
        visible: !root.grouped
        iconText: root.service.mutedSources.indexOf(Model.source(root.row)) >= 0 ? "󰂚" : "󰂛"
        tooltipText: root.service.mutedSources.indexOf(Model.source(root.row)) >= 0 ? root.strings.t("unmute") : root.strings.t("mute")
        focusable: true
        onClicked: root.service.mute(Model.source(root.row))
      }
    }
  }
  }
}
