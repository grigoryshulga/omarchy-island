// Supplemental ANSI/named colors not exposed as roles by qs.Commons.Color.
function parse(raw) {
  var values={}, aliases={color1:"red",color2:"green",color3:"yellow",color4:"blue"}, named={}
  String(raw || "").split("\n").forEach(function(line) {
    var match=line.match(/^\s*([a-z0-9_]+)\s*=\s*["']?(#[0-9a-fA-F]{6})(?:["']?\s*(?:#.*)?)$/)
    if(!match) return
    var key=match[1]
    if(aliases[key]) values[aliases[key]]=match[2]
    else if(["red","green","yellow","blue"].indexOf(key)>=0) named[key]=match[2]
  })
  Object.keys(named).forEach(function(key){values[key]=named[key]})
  return values
}
if(typeof module!=="undefined") module.exports={parse:parse}
