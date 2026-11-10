import QtQuick

QtObject {
  required property Item surface
  required property var effect
  required property var hover
  function pulseFrom(item, position) {
    var at=position!==undefined ? item.mapToItem(surface,position.x,position.y) : item.mapToItem(surface,item.width/2,item.height/2)
    if(position===undefined && hover.hovered) {
      var p=hover.point.position, local=item.mapFromItem(surface,p.x,p.y)
      if(local.x>=0 && local.y>=0 && local.x<=item.width && local.y<=item.height) at=p
    }
    effect.pulse(at)
  }
}
