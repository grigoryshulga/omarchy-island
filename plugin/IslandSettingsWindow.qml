pragma Singleton
import QtQuick
import qs.Commons
import qs.Commons as Commons

Window {
  id:root
  property Item host:null
  readonly property alias view:loader.item
  visible:false
  flags:Qt.Window
  transientParent:null
  title:translations.t("settings.title")
  color:Design.opaqueCanvas
  width:Style.space(820);height:Style.space(660)
  minimumWidth:Style.space(300);minimumHeight:Style.space(240)
  Commons.Translations {id:translations;directory:Qt.resolvedUrl("i18n")}
  function present(source,groupId) {
    host=source
    if (!visible) {
      var output=Qt.application.screens.find(item=>item.name===source.Screen.name)
      if (output) screen=output
      width=Math.min(width,Screen.desktopAvailableWidth || width)
      height=Math.min(height,Screen.desktopAvailableHeight || height)
      showNormal()
    } else if(visibility===Window.Minimized) {
      showNormal()
    }
    requestActivate()
    Qt.callLater(function(){if(root.visible && loader.item && !loader.item.focusGroup(groupId)) loader.item.focusContent()})
  }
  onHostChanged:if(!host && visible) close()
  onVisibleChanged:if(!visible) host=null
  KeyboardNavigation {id:navigation;scope:root.contentItem}
  onActiveFocusItemChanged:if(activeFocusItem) navigation.revealItem(activeFocusItem)
  Item {
    anchors.fill:parent;anchors.margins:Design.gap.large
    PlainText {
      LayoutMirroring.enabled:Commons.I18n.rightToLeft
      anchors.left:parent.left;anchors.right:closeButton.left
      anchors.verticalCenter:closeButton.verticalCenter
      text:root.title;typeRole:"page"
      Accessible.role:Accessible.Heading
    }
    FeedbackButton {
      id:closeButton;objectName:"settingsWindowClose"
      LayoutMirroring.enabled:Commons.I18n.rightToLeft
      anchors.top:parent.top;anchors.right:parent.right
      iconText:"×";tooltipText:translations.t("close");focusable:true
      onClicked:root.close()
    }
    Loader {
      id:loader
      anchors.top:closeButton.bottom;anchors.topMargin:Design.gap.medium
      anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
      active:root.visible && !!root.host
      sourceComponent:SettingsView {
        objectName:"islandWindowSettings"
        windowMode:true
        strings:root.host ? root.host.strings : translations
        settings:root.host ? root.host.settings : ({})
        service:root.host ? root.host.service : null
        bar:root.host ? root.host.bar : null
        modules:service && service.modules ? service.modules : ({})
        onSettingRequested:(key,value)=>{if(root.host) root.host.settingRequested(key,value)}
      }
    }
    Keys.priority:Keys.AfterItem
    Keys.onEscapePressed:event=>{
      if(!loader.item || !loader.item.dismissEditor()) root.close()
      event.accepted=true
    }
  }
  Shortcut {sequences:[StandardKey.Close];context:Qt.WindowShortcut;enabled:root.active;onActivated:root.close()}
}
