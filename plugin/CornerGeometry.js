// QML-compatible superellipse contours. Radius is in layout pixels, power is
// Hyprland decoration:rounding_power (2 = circle, 4 = squircle).
function power(value) {
  return typeof value === "number" && isFinite(value) ? Math.max(1,Math.min(10,value)) : 2
}
function parsePower(raw, previous) {
  try {
    var value=JSON.parse(raw).float
    return typeof value === "number" && isFinite(value) ? power(value) : previous
  } catch(e) { return previous }
}
function contour(width,height,radius,exponent,insets) {
  var p=power(exponent), s=insets || {}, l=s.left || 0, t=s.top || 0
  var right=width-(s.right || 0), bottom=height-(s.bottom || 0)
  if(right<=l || bottom<=t) return ""
  var r=Math.max(0,Math.min(radius,width/2,height/2))
  var rxLeft=Math.max(0,r-l), rxRight=Math.max(0,r-(s.right || 0))
  var ryTop=Math.max(0,r-t), ryBottom=Math.max(0,r-(s.bottom || 0))
  var corners=[
    [right-rxRight,t+ryTop,rxRight,ryTop,1,-1],
    [right-rxRight,bottom-ryBottom,rxRight,ryBottom,1,1],
    [l+rxLeft,bottom-ryBottom,rxLeft,ryBottom,-1,1],
    [l+rxLeft,t+ryTop,rxLeft,ryTop,-1,-1]
  ]
  var points=[], diagonal=Math.pow(0.5,1/p)
  // Split at the diagonal and sample each half along its shorter coordinate.
  // Unlike uniform angular sampling this stays smooth even at power 10.
  for(var c=0;c<4;c++) {
    var corner=corners[c]
    for(var i=0;i<=64;i++) {
      var v=(i<=32 ? i : 64-i)/32*diagonal
      var u=Math.pow(Math.max(0,1-Math.pow(v,p)),1/p)
      var x=i<=32 ? v : u, y=i<=32 ? u : v
      if(c%2===1) {var swap=x;x=y;y=swap}
      points.push((corner[0]+corner[4]*corner[2]*x).toFixed(4)+","+(corner[1]+corner[5]*corner[3]*y).toFixed(4))
    }
  }
  return "M"+points.join(" L")+" Z"
}
function endpoints(width,height,angle) {
  var a=(angle || 0)*Math.PI/180, dx=Math.cos(a), dy=Math.sin(a)
  var extent=(Math.abs(width*dx)+Math.abs(height*dy))/2
  return {x1:width/2-dx*extent,y1:height/2-dy*extent,x2:width/2+dx*extent,y2:height/2+dy*extent}
}
