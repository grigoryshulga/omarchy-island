import QtQuick
import qs.Commons
import "vendor/lucide/Icons.js" as Lucide

Item {
  id:root
  property var icon:null
  readonly property string kind:icon && icon.kind ? icon.kind : ""
  readonly property string label:kind==="emoji" ? icon.emoji : kind==="monogram" ? icon.text : ""
  readonly property string geometry:kind==="lucide" && Object.prototype.hasOwnProperty.call(Lucide.paths,icon.name) ? Lucide.paths[icon.name] : Lucide.paths.folder
  implicitWidth:Style.space(16)
  implicitHeight:implicitWidth
  Image {
    objectName:"projectLucideIcon"
    anchors.fill:parent
    visible:root.label===""
    source:"data:image/svg+xml,"+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="'+Design.accent+'" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'+root.geometry+'</svg>')
    sourceSize.width:width;sourceSize.height:height
  }
  PlainText {
    anchors.fill:parent
    visible:root.label!==""
    text:root.label
    typeRole:"caption"
    color:Design.accent
    horizontalAlignment:Text.AlignHCenter
    verticalAlignment:Text.AlignVCenter
    fontSizeMode:Text.Fit
    minimumPixelSize:Style.space(6)
  }
}
