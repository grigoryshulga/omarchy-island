import QtQuick
import QtQuick.Window

QtObject {
  id:root
  objectName:"islandKeyboardNavigation"
  required property Item scope
  property var containers:[]
  readonly property var focused:scope.Window.window ? scope.Window.window.activeFocusItem : null
  function contains(parent,item) {
    while(item) {if(item===parent) return true;item=item.parent}
    return false
  }
  function nativeFocus() {
    if(focused && "islandExternalNavigation" in focused && focused.islandExternalNavigation) return false
    for(var item=focused;item && item!==scope;item=item.parent)
      if("keyboardTarget" in item && item.keyboardTarget) return true
    return false
  }
  function editing(item) {
    while(item && item!==scope) {
      if(typeof item.cursorPosition==="number" && typeof item.text==="string") return true
      item=item.parent
    }
    return false
  }
  function collect(item,result) {
    if(!item || !item.visible || !item.enabled || item.opacity<0.01 || item.width<=0 || item.height<=0) return
    if("keyboardTarget" in item && item.keyboardTarget && result.indexOf(item.keyboardTarget)<0) result.push(item.keyboardTarget)
    if(item.activeFocusOnTab) {
      if(result.indexOf(item)<0) result.push(item)
      if(!("islandNavigationContainer" in item && item.islandNavigationContainer)) return
    }
    for(var i=0;i<item.children.length;i++) collect(item.children[i],result)
  }
  function candidates() {var result=[];for(var i=0;i<containers.length;i++) collect(containers[i],result);return result}
  function focusItem(item) {
    if(!item) return
    item.forceActiveFocus(Qt.TabFocusReason)
    // Keyboard navigation reveals offscreen notification rows without changing
    // the horizontal page position or relying on the pointer to scroll them.
    for(var parent=item.parent;parent && parent!==scope;parent=parent.parent) {
      if("contentY" in parent && "contentHeight" in parent && parent.contentItem && parent.contentHeight>parent.height) {
        var at=item.mapToItem(parent.contentItem,0,0),y=parent.contentY
        if(at.y<y) y=at.y
        else if(at.y+item.height>y+parent.height) y=at.y+item.height-parent.height
        parent.contentY=Math.max(0,Math.min(parent.contentHeight-parent.height,y))
      }
    }
  }
  function tab(direction) {
    var items=candidates();if(!items.length) return
    var current=items.indexOf(focused)
    if(current<0) for(var i=0;i<items.length;i++) if(contains(items[i],focused)) {current=i;break}
    var next=current<0 ? (direction>0 ? 0 : items.length-1) : (current+direction+items.length)%items.length
    focusItem(items[next])
  }
  function first(container) {var items=[];collect(container,items);if(items.length) focusItem(items[0])}
  function move(dx,dy) {
    if(editing(focused)) return false
    var items=candidates()
    if(items.indexOf(focused)<0) {if(items.length) focusItem(items[0]);return items.length>0}
    var from=focused.mapToItem(scope,focused.width/2,focused.height/2),origin=focused.mapToItem(scope,0,0),best=null,score=Infinity
    for(var i=0;i<items.length;i++) {
      var item=items[i];if(item===focused) continue
      var at=item.mapToItem(scope,item.width/2,item.height/2),x=at.x-from.x,y=at.y-from.y
      var forward=dx ? x*dx : y*dy,cross=dx ? Math.abs(y) : Math.abs(x)
      if(forward<=1) continue
      var corner=item.mapToItem(scope,0,0)
      var aligned=dx ? corner.y<origin.y+focused.height && corner.y+item.height>origin.y : corner.x<origin.x+focused.width && corner.x+item.width>origin.x
      var distance=(aligned ? 0 : 1000000)+forward+cross*2.5
      if(distance<score) {score=distance;best=item}
    }
    if(best) focusItem(best)
    return true
  }
  function direction(event) {
    if(event.modifiers & (Qt.AltModifier|Qt.ControlModifier|Qt.MetaModifier)) return null
    var text=String(event.text || "").toLowerCase()
    if(event.key===Qt.Key_Left || text==="h" || text==="р") return {x:-1,y:0,key:Qt.Key_Left}
    if(event.key===Qt.Key_Right || text==="l" || text==="д") return {x:1,y:0,key:Qt.Key_Right}
    if(event.key===Qt.Key_Up || text==="k" || text==="л") return {x:0,y:-1,key:Qt.Key_Up}
    if(event.key===Qt.Key_Down || text==="j" || text==="о") return {x:0,y:1,key:Qt.Key_Down}
    return null
  }
}
