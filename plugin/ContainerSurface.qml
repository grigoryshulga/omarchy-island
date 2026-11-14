import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Ui
import "CornerGeometry.js" as Geometry

// Containers use the compositor's corner profile. Native rendering remains the
// inexpensive path for circular/square corners; controls keep their native UI.
Item {
  id:root
  property color color:"transparent"
  property real radius:0
  property real roundingPower:CornerStyle.roundingPower
  property var borderSpec:Border.flat(border.color,border.width)
  component BorderProperties:QtObject {property real width:0;property color color:"transparent"}
  property BorderProperties border:BorderProperties {}
  property real padding:0
  property real topPadding:padding
  property real rightPadding:padding
  property real bottomPadding:padding
  property real leftPadding:padding
  readonly property real borderTop:Border.top(borderSpec)
  readonly property real borderRight:Border.right(borderSpec)
  readonly property real borderBottom:Border.bottom(borderSpec)
  readonly property real borderLeft:Border.left(borderSpec)
  readonly property real contentTopInset:borderTop+topPadding
  readonly property real contentRightInset:borderRight+rightPadding
  readonly property real contentBottomInset:borderBottom+bottomPadding
  readonly property real contentLeftInset:borderLeft+leftPadding
  readonly property bool usesOverlayBorder:Border.needsOverlay(borderSpec)
  readonly property bool customCorners:radius>0 && Geometry.power(roundingPower)!==2
  Loader {
    anchors.fill:parent
    active:!root.customCorners
    sourceComponent:BorderSurface {color:root.color;radius:root.radius;borderSpec:root.borderSpec}
  }
  Loader {
    anchors.fill:parent
    active:root.customCorners
    sourceComponent:Item {
      id:profile
      readonly property string outline:Geometry.contour(width,height,root.radius,root.roundingPower)
      readonly property string inner:Geometry.contour(width,height,root.radius,root.roundingPower,{top:root.borderTop,right:root.borderRight,bottom:root.borderBottom,left:root.borderLeft})
      readonly property var gradient:root.borderSpec.gradient
      readonly property var colors:gradient && gradient.enabled ? gradient.colors : [Border.color(root.borderSpec)]
      readonly property var endpoints:Geometry.endpoints(width,height,gradient ? gradient.angle : 0)
      function stopColor(index) {return colors[Math.min(index,colors.length-1)]}
      function stopPosition(index) {return Math.min(1,index/Math.max(1,colors.length-1))}
      Shape {
        anchors.fill:parent
        preferredRendererType:Shape.CurveRenderer
        ShapePath {strokeWidth:0;fillColor:root.color;PathSvg {path:profile.outline}}
      }
      Shape {
        anchors.fill:parent
        z:100000
        visible:Math.max(root.borderTop,root.borderRight,root.borderBottom,root.borderLeft)>0
        preferredRendererType:Shape.CurveRenderer
        ShapePath {
          strokeWidth:0
          fillRule:ShapePath.OddEvenFill
          fillGradient:LinearGradient {
            x1:profile.endpoints.x1;y1:profile.endpoints.y1;x2:profile.endpoints.x2;y2:profile.endpoints.y2
            GradientStop {position:profile.stopPosition(0);color:profile.stopColor(0)}
            GradientStop {position:profile.stopPosition(1);color:profile.stopColor(1)}
            GradientStop {position:profile.stopPosition(2);color:profile.stopColor(2)}
            GradientStop {position:profile.stopPosition(3);color:profile.stopColor(3)}
            GradientStop {position:profile.stopPosition(4);color:profile.stopColor(4)}
            GradientStop {position:profile.stopPosition(5);color:profile.stopColor(5)}
            GradientStop {position:profile.stopPosition(6);color:profile.stopColor(6)}
            GradientStop {position:profile.stopPosition(7);color:profile.stopColor(7)}
            GradientStop {position:profile.stopPosition(8);color:profile.stopColor(8)}
            GradientStop {position:profile.stopPosition(9);color:profile.stopColor(9)}
          }
          PathSvg {path:profile.outline+" "+profile.inner}
        }
      }
    }
  }
}
