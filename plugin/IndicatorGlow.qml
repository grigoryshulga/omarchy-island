import QtQuick
import qs.Commons

// Compact status light on the same fixed-pitch braille field as the cursor.
// The center is denser, with a soft edge and no raster blur or moving waves.
BrailleSpotlight {
  objectName:"controlIndicatorGlow"
  width:Style.space(48)
  height:width
  spotRadius:Math.min(width,height)/2
  cornerRadius:0
  artworkStrength:0
  pointer:Qt.point(width/2,height/2)
  intensity:2.8
  opacity:1
}
