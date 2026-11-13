import QtQuick
import QtQml.Models
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "SettingsModel.mjs" as Settings
import "ModuleCatalog.mjs" as Catalog

Item {
  id: root
  required property var service
  required property var strings
  property var bar: null
  property var settings: ({})
  property var externalFeedback: null
  readonly property bool musicHovered: selectedPage===1 && !!pageObject(1) && pageObject(1).interactionHovered
  property bool keyboardActive: false
  property bool expanded: false
  property bool hovering: false
  property string alertKind: ""
  readonly property bool mediaToast:alertKind==="media" && !expanded && !hovering
  readonly property var notificationIcon: pageObject(1) ? pageObject(1).toastIcon : null
  property int selectedPage:1
  readonly property string detailPage:currentPage() && ("detailPage" in currentPage()) ? currentPage().detailPage : ""
  readonly property bool controls:detailPage==="controls"
  readonly property bool calendar:selectedPage===2
  readonly property bool weather:selectedPage===3
  readonly property var pageDefinitions:Catalog.pages()
  property bool compactNotifications: !expanded && !hovering && alertKind==="notification"
  readonly property var weatherData: service && ("weather" in service) ? service.weather : null
  readonly property int lastPage: weatherData && weatherData.allowed ? 3 : 2
  readonly property string pageSignature:{
    var result=Settings.pages(settings,lastPage===3)
    if(!expanded && alertKind && result.indexOf(1)<0) result.splice(1,0,1)
    return result.join(",")
  }
  readonly property var enabledPages:pageSignature.split(",").map(Number)
  property bool radialBraille: true
  property bool ready: false
  property real wheelDistance: 0
  property int wheelDirection: 0
  property bool wheelLatched: false
  property bool positioned: false
  property bool navigating: false
  property bool gesturing: false
  property int edgeTarget: -1
  property bool wrapping: false
  signal dismissRequested()
  signal settingRequested(string key, var value)
  signal expandRequested()
  signal pageRequested(int index)
  readonly property real pageProgress: wrapping ? 1 : pager.width>0 && pager.itemAt(enabledPages.indexOf(1)) ? Math.max(0,Math.min(1,Math.abs((pager.contentItem.contentX-pager.itemAt(enabledPages.indexOf(1)).x)/pager.width))) : (selectedPage!==1 ? 1 : 0)
  readonly property bool settingsOpen:!!currentPage() && currentPage().navigationHidden
  // Keep the popup surface size while Settings uses the space of the hidden tabs.
  readonly property real navigationHeight: expanded && visible ? tabs.implicitHeight+Design.gap.section : 0
  readonly property real contentTop: tabs.visible ? navigationHeight : 0
  readonly property real calendarWeatherHeight: {
    var result=0
    for(var i=0;i<pageDefinitions.length;i++) {var page=pageObject(pageDefinitions[i].pageIndex);if(page) result=Math.max(result,page.stableHeight)}
    return result
  }
  implicitHeight:navigationHeight+Math.max(root.expanded ? calendarWeatherHeight : 0,currentPage() ? currentPage().implicitHeight : 0)
  clip:true
  function pageHolder(index) {
    for(var i=0;i<pageHolders.count;i++) {var holder=pageHolders.objectAt(i);if(holder && holder.pageIndex===index) return holder}
    return null
  }
  function pageObject(index) {var holder=pageHolder(index);return holder ? holder.view.item : null}
  function currentPage() {return pageObject(selectedPage)}
  function enterPage(index) {var page=pageObject(index);if(page) page.enter()}
  function openDetails(id) {var page=pageObject(1);if(page && typeof page.openDetails==="function") page.openDetails(id)}
  function showToday() {enterPage(2)}
  function back() {return currentPage() ? currentPage().back() : false}
  function updatePages() {
    if(!ready) return
    if(enabledPages.indexOf(selectedPage)<0) pageRequested(enabledPages[0])
    for(var i=pager.count-1;i>=0;i--) {
      var item=pager.itemAt(i)
      if(enabledPages.indexOf(item.pageIndex)<0) {pager.takeItem(i);item.parent=parking}
    }
    for(var at=0;at<enabledPages.length;at++) {
      var target=pageHolder(enabledPages[at]),from=-1
      if(!target) continue
      for(var j=0;j<pager.count;j++) if(pager.itemAt(j)===target) {from=j;break}
      if(from<0) pager.insertItem(at,target)
      else if(from!==at) pager.moveItem(from,at)
    }
    scheduleSync()
  }
  function cancelEdits() {for(var i=0;i<pageDefinitions.length;i++){var page=pageObject(pageDefinitions[i].pageIndex);if(page) page.cancelEditing()}}
  function handleCalendarKey(event) {var page=pageObject(2);return page ? page.handleKey(event) : false}
  function keyboardPage(index) {
    if(!keyboardActive || enabledPages.indexOf(index)<0) return
    enterPage(index)
    requestPage(index)
    Qt.callLater(function(){var page=root.currentPage();if(page && !page.focusPrimary()) navigation.first(page)})
  }
  function directionEnabled(horizontal) {
    return keyboardActive && !(currentPage() && currentPage().ownsKeys) && navigation.contains(root,navigation.focused) && !navigation.editing(navigation.focused) && !navigation.nativeFocus() && !(horizontal && navigation.focused && "islandHandlesHorizontalKeys" in navigation.focused)
  }
  function keyboardDirection(x,y) {
    var page=currentPage(),event={key:x<0 ? Qt.Key_Left : x>0 ? Qt.Key_Right : y<0 ? Qt.Key_Up : Qt.Key_Down}
    if(page && page.handleKey(event)) Qt.callLater(function(){page.focusPrimary()})
    else navigation.move(x,y)
  }
  function handleKeyboard(event) {
    if(!keyboardActive || navigation.editing(navigation.focused)) return false
    var page=currentPage(),direction=navigation.direction(event)
    if(page && page.handleKey(direction ? {key:direction.key} : event)) return true
    return direction ? navigation.move(direction.x,direction.y) : false
  }
  KeyboardNavigation {id:navigation;scope:root;containers:[tabs,root.currentPage()]}
  Instantiator {
    model:Catalog.ordered("overview").filter(function(entry){return !!entry.overviewShortcut})
    delegate:Shortcut {
      required property var modelData
      sequence:modelData.overviewShortcut;context:Qt.WindowShortcut;enabled:root.keyboardActive
      onActivated:{root.keyboardPage(1);root.openDetails(modelData.id)}
    }
  }
  Shortcut {sequence:"Alt+2";context:Qt.WindowShortcut;enabled:root.keyboardActive;onActivated:root.keyboardPage(1)}
  Shortcut {sequence:"Alt+3";context:Qt.WindowShortcut;enabled:root.keyboardActive;onActivated:root.keyboardPage(2)}
  Shortcut {sequence:"Alt+4";context:Qt.WindowShortcut;enabled:root.keyboardActive && root.lastPage===3;onActivated:root.keyboardPage(3)}
  Shortcut {sequence:"Tab";context:Qt.WindowShortcut;enabled:root.keyboardActive && navigation.contains(root,navigation.focused);onActivated:navigation.tab(1)}
  Shortcut {sequence:"Shift+Tab";context:Qt.WindowShortcut;enabled:root.keyboardActive && navigation.contains(root,navigation.focused);onActivated:navigation.tab(-1)}
  Shortcut {sequences:["Left","H","Р"];context:Qt.WindowShortcut;enabled:root.directionEnabled(true);onActivated:root.keyboardDirection(-1,0)}
  Shortcut {sequences:["Right","L","Д"];context:Qt.WindowShortcut;enabled:root.directionEnabled(true);onActivated:root.keyboardDirection(1,0)}
  Shortcut {sequences:["Up","K","Л"];context:Qt.WindowShortcut;enabled:root.directionEnabled(false);onActivated:root.keyboardDirection(0,-1)}
  Shortcut {sequences:["Down","J","О"];context:Qt.WindowShortcut;enabled:root.directionEnabled(false);onActivated:root.keyboardDirection(0,1)}
  Keys.priority:Keys.AfterItem
  Keys.onPressed:event=>{event.accepted=root.handleKeyboard(event)}
  function syncPage() {
    if(!ready || pager.width<=0) return
    var view=pager.contentItem
    if(view.dragging || view.flicking) return
    var next=Math.max(0,enabledPages.indexOf(selectedPage))
    pageMotion.stop()
    var from=view.contentX
    pager.setCurrentIndex(next)
    view.forceLayout()
    var page=pager.itemAt(next)
    if(!page) return
    var target=page.x
    if(!positioned || Math.abs(from-target)<0.5 || Preferences.reduceMotion) {view.contentX=target;wrapping=false}
    else {
      view.contentX=from
      pageMotion.from=from;pageMotion.to=target;pageMotion.restart()
    }
    positioned=true
  }
  function scheduleSync() { if(ready) Qt.callLater(syncPage) }
  function finishGesture() {
    if(navigating || !gesturing) return
    gesturing=false
    if(edgeTarget>=0) {var target=edgeTarget;edgeTarget=-1;requestPage(target);return}
    var closest=0,distance=Infinity
    pager.contentItem.forceLayout()
    for(var i=0;i<enabledPages.length;i++) {
      var page=pager.itemAt(i),delta=page ? Math.abs(pager.contentItem.contentX-page.x) : Infinity
      if(delta<distance) {distance=delta;closest=i}
    }
    requestPage(enabledPages[closest])
  }
  function handleWheel(event) {
    var x=event.pixelDelta.x || event.angleDelta.x
    var y=event.pixelDelta.y || event.angleDelta.y
    if (event.modifiers & Qt.ShiftModifier) x=x || y
    if (!root.expanded || !x || (!(event.modifiers & Qt.ShiftModifier) && Math.abs(x)<Math.abs(y))) { event.accepted=false; return }
    event.accepted=true
    var sign=x<0 ? -1 : 1
    if (sign!==root.wheelDirection) { root.wheelDistance=0; root.wheelLatched=false }
    root.wheelDirection=sign
    wheelIdle.restart()
    if (root.wheelLatched) return
    root.wheelDistance+=x
    var threshold=event.pixelDelta.x || event.pixelDelta.y ? 40 : 90
    if (Math.abs(root.wheelDistance)<threshold) return
    var step=(Commons.I18n.rightToLeft ? sign>0 : sign<0) ? 1 : -1
    var next=Settings.nextPage(enabledPages,selectedPage,step)
    root.wheelLatched=true
    requestPage(next)
  }
  function requestPage(index) {
    if(enabledPages.indexOf(index)<0) return
    if(index===selectedPage) enterPage(index)
    wrapping=(pager.currentIndex===0 && index===enabledPages[enabledPages.length-1]) || (pager.currentIndex===enabledPages.length-1 && index===0)
    edgeTarget=-1
    gesturing=false
    navigating=true
    pageMotion.stop()
    pager.contentItem.cancelFlick()
    navigating=false
    if(index!==selectedPage) pageRequested(index)
    scheduleSync()
  }
  onSelectedPageChanged:scheduleSync()
  onWidthChanged: scheduleSync()
  onHeightChanged: scheduleSync()
  onLastPageChanged: if(ready) {if(weather && lastPage<3) pageRequested(1);else scheduleSync()}
  onEnabledPagesChanged:Qt.callLater(updatePages)
  Component.onCompleted: { ready = true; updatePages(); scheduleSync() }

  RowLayout {
    id: tabs
    objectName: "islandTabs"
    anchors.left: parent.left; anchors.right: parent.right
    visible: root.expanded && !root.settingsOpen
    spacing:Design.gap.tight
    uniformCellSizes: true
    Repeater {
      model:root.pageDefinitions
      ModuleSlot {
        id:tabSlot
        required property var modelData
        Layout.fillWidth:true;Layout.fillHeight:true;Layout.preferredWidth:1;Layout.minimumWidth:0
        visible:root.enabledPages.indexOf(modelData.pageIndex)>=0
        viewSource:modelData.tab || "ModuleTab.qml"
        backend:root.service && root.service.modules ? root.service.modules[modelData.id] || null : null
        presentation:QtObject {
          readonly property string title:tabSlot.modelData.title || root.strings.t(tabSlot.modelData.titleKey)
          readonly property string objectName:tabSlot.modelData.tabObjectName || "moduleTab-"+tabSlot.modelData.id
          readonly property bool selected:root.selectedPage===tabSlot.modelData.pageIndex
          readonly property var feedback:root.externalFeedback
          readonly property var strings:root.strings
        }
        onDetailsRequested:root.requestPage(modelData.pageIndex)
        onCustomizeRequested:{
          var page=root.pageObject(tabSlot.modelData.pageIndex)
          if(root.expanded && root.selectedPage===tabSlot.modelData.pageIndex && page && typeof page.configure==="function") page.configure(tabSlot.item.focusTarget)
        }
      }
    }
  }

  Controls.SwipeView {
    id: pager
    objectName: "islandPageSwipe"
    currentIndex: 1
    x: 0; y: root.contentTop
    width: parent.width; height: Math.max(0,parent.height-y)
    interactive: root.expanded
    // Native flicking owns gestures; explicit navigation owns the settled
    // position. Do not let ListView's highlight fight the page transition.
    Binding {target:pager.contentItem;property:"boundsBehavior";value:Flickable.DragOverBounds}
    Binding { target: pager.contentItem; property: "highlightRangeMode"; value: ListView.NoHighlightRange }
    Binding { target: pager.contentItem; property: "highlightFollowsCurrentItem"; value: false }
  }
  Item {id:parking;visible:false}
  Instantiator {
    id:pageHolders
    model:root.pageDefinitions
    onObjectAdded:Qt.callLater(root.updatePages)
    delegate:Item {
      id:holder
      required property var modelData
      readonly property int pageIndex:modelData.pageIndex
      readonly property alias view:pageView
      parent:parking
      ModuleSlot {
        id:pageView
        anchors.fill:parent
        viewSource:holder.modelData.page
        backend:root.service && root.service.modules ? root.service.modules[holder.modelData.id] || null : null
        presentation:QtObject {
          readonly property var service:root.service
          readonly property var strings:root.strings
          readonly property var bar:root.bar
          readonly property var settings:root.settings
          readonly property var feedback:root.externalFeedback
          readonly property var focusedItem:navigation.focused
          readonly property bool selected:root.selectedPage===holder.pageIndex
          readonly property bool active:selected && root.visible && (root.expanded || root.hovering)
          readonly property bool expanded:root.expanded
          readonly property bool hovering:root.hovering
          readonly property string alertKind:root.alertKind
          readonly property bool radialBraille:root.radialBraille
          readonly property real pageHeight:root.calendarWeatherHeight
        }
        onCloseRequested:root.dismissRequested()
        onExpandRequested:root.expandRequested()
        onSettingRequested:(key,value)=>root.settingRequested(key,value)
      }
    }
  }

  NumberAnimation { id: pageMotion; onFinished:root.wrapping=false; target: pager.contentItem; property: "contentX"; duration: Preferences.duration(230); easing.type: Easing.OutCubic }
  Connections {target:Preferences;function onReduceMotionChanged(){if(Preferences.reduceMotion) {pageMotion.stop();root.scheduleSync()}}}
  Connections {
    target: pager.contentItem
    function onDraggingChanged() {if(pager.contentItem.dragging) {root.gesturing=true;root.edgeTarget=-1;pageMotion.stop()}}
    function onContentXChanged() {
      var view=pager.contentItem
      if(!root.gesturing || !view.dragging) return
      var first=pager.itemAt(0),last=pager.itemAt(root.enabledPages.length-1)
      if(!first || !last) return
      var low=Math.min(first.x,last.x),high=Math.max(first.x,last.x),threshold=Style.space(40)
      root.edgeTarget=view.contentX<low-threshold ? (first.x<last.x ? root.enabledPages[root.enabledPages.length-1] : root.enabledPages[0]) : view.contentX>high+threshold ? (first.x<last.x ? root.enabledPages[0] : root.enabledPages[root.enabledPages.length-1]) : -1
    }
    function onMovementEnded() {root.finishGesture()}
    function onContentWidthChanged() {root.scheduleSync()}
  }
  // Wheel-only overlay: horizontal events reach us before child Flickables;
  // pointer presses and vertical scrolling continue to the page underneath.
  Item {
    anchors.fill: parent
    z: 100
    WheelHandler {
      target: null
      orientation: Qt.Horizontal
      acceptedModifiers: Qt.NoModifier
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => root.handleWheel(event)
    }
    WheelHandler {
      target: null
      orientation: Qt.Vertical
      acceptedModifiers: Qt.ShiftModifier
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => root.handleWheel(event)
    }
  }
  Timer { id: wheelIdle; interval: 180; onTriggered: { root.wheelDistance=0; root.wheelLatched=false; root.wheelDirection=0 } }
}
