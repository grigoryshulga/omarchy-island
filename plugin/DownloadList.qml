import QtQuick
import qs.Commons

Column {
  id:root
  required property var rows
  required property var service
  required property var strings
  property bool expanded:false
  spacing:Style.space(6)
  // Keep delegates and pointer focus stable as byte counts change.
  function sync() {
    for(var i=0;i<rows.length;i++) {
      var row=rows[i],found=-1
      for(var j=i;j<items.count;j++) if(items.get(j).key===row.key) {found=j;break}
      if(found<0) items.insert(i,row)
      else {
        if(found!==i) items.move(found,i,1)
        for(var key in row) if(items.get(i)[key]!==row[key]) items.setProperty(i,key,row[key])
      }
    }
    if(items.count>rows.length) items.remove(rows.length,items.count-rows.length)
  }
  onRowsChanged:sync()
  Component.onCompleted:sync()
  ListModel {id:items}
  Repeater {
    model:items
    DownloadCard {
      required property var model
      width:root.width
      row:model
      service:root.service;strings:root.strings;expanded:root.expanded
    }
  }
}
