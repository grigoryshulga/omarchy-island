import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "ClockLayout.mjs" as ClockLayout
import "ModuleCatalog.mjs" as Catalog
import "ClockModel.js" as Clock

Column {
  id:root;objectName:"clockLayoutEditor"
  required property var strings
  required property Flickable scrollViewport
  property var settings:({})
  property var service:null
  property var bar:null
  property bool active:true
  property bool vertical:bar ? bar.vertical : false
  property string selectedId:"clock"
  property bool customFormatOpen:false
  readonly property var entries:ClockLayout.catalog(Catalog.ordered("indicator"))
  readonly property var elements:ClockLayout.layout(entries,settings.clockLayout,settings)
  readonly property var selectedRow:elements.find(function(row){return row.id===selectedId}) || null
  readonly property string side:selectedRow ? selectedRow.side : "right"
  readonly property string formatKey:vertical ? "verticalFormat" : "format"
  readonly property string format:String(settings[formatKey] || (vertical ? "HH\n—\nmm" : "dddd HH:mm"))
  property date now:new Date()
  readonly property bool ownsKeys:board.dragged!=="" || addMenu.popupOpen || formats.popupOpen || customFormat.activeFocus
  signal settingRequested(string key,var value)
  signal revealFocus(var item)
  spacing:Design.gap.medium
  onElementsChanged:if(selectedId!=="clock" && !elements.some(function(row){return row.id===root.selectedId})) selectedId="clock"
  function closeEditors() {board.cancel();addMenu.close();formats.close();customFormat.focus=false;customFormatOpen=false}
  function formatted(value) {
    var week=Clock.isoWeekLiteral(now.getFullYear(),now.getMonth(),now.getDate()).split("").map(function(d){return Commons.I18n.formatNumber(d)}).join("")
    return now.toLocaleString(Qt.locale(Commons.I18n.formatLocale),value.replace(/ww/g,week))
  }
  function save(rows,id) {
    selectedId=id || selectedId
    settingRequested("clockLayout",rows)
    Qt.callLater(function(){board.focusElement(root.selectedId)})
  }
  function add(id) {
    var rows=ClockLayout.add(elements,id,side)
    if(rows.length>elements.length) save(rows,rows[rows.length-1].id)
  }
  function remove() {
    save(elements.filter(function(row){return row.id!==root.selectedId}),"clock")
    clockButton.forceActiveFocus()
  }
  function elementIcon(row) {
    if(row.kind==="space") return "↔"
    if(row.kind==="separator") return "│"
    var entry=entries.find(item=>item.id===row.id)
    return entry ? entry.icon : "◇"
  }
  function elementTitle(row) {return left.title(row)}
  function reorder(id,side,before) {save(ClockLayout.move(elements,id,side,before),id)}
  function move(step) {save(ClockLayout.step(elements,selectedId,step))}
  function drop(id,item,dx,dy) {
    var point=item.mapToItem(stage,item.width/2+dx,item.height/2+dy)
    var side=vertical ? (point.y<clockButton.y+clockButton.height/2 ? "left" : "right") : (point.x<clockButton.x+clockButton.width/2 ? "left" : "right")
    var positions=(side==="left" ? left : right).positions(stage).filter(function(p){return p.id!==id})
    var before=positions.find(function(p){return vertical ? point.y<p.y : point.x<p.x})
    save(ClockLayout.move(elements,id,side,before ? before.id : ""),id)
  }
  Timer {interval:1000;repeat:true;running:root.visible && root.active;onTriggered:root.now=new Date()}
  Row {
    width:parent.width;spacing:Design.gap.small
    layoutDirection:Commons.I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
    SectionHeading {width:Math.max(0,parent.width-orientation.width-reset.width-2*parent.spacing);title:root.strings.t("clock.title")}
    FeedbackButton {
      id:orientation;objectName:"clockOrientation";iconSize:fontSize;iconText:root.vertical ? "↕" : "↔";compact:true;focusable:true
      tooltipText:root.strings.t(root.vertical ? "clock.vertical" : "clock.horizontal")
      onClicked:{root.closeEditors();root.vertical=!root.vertical}
    }
    FeedbackButton {
      id:reset;objectName:"clockReset";iconSize:fontSize;iconText:"↺";compact:true;focusable:true
      tooltipText:root.strings.t("clock.reset")
      onClicked:{root.selectedId="clock";root.settingRequested("clockLayout",null)}
    }
  }
  Rectangle {
    width:parent.width;height:preview.height+2*Design.gap.large
    radius:Design.cardRadius;color:Design.raised
    Flickable {
      id:preview
      x:Design.gap.large;y:Design.gap.large
      width:parent.width-2*x
      height:root.vertical ? stage.height : Math.max(Style.space(52),stage.height)
      contentWidth:stage.width;contentHeight:stage.height
      clip:true;boundsBehavior:Flickable.StopAtBounds
      flickableDirection:Flickable.HorizontalFlick
      function centerClock() {
        if (!dragging && root.selectedId==="clock") contentX=Math.max(0,(contentWidth-width)/2)
      }
      onWidthChanged:Qt.callLater(centerClock)
      onContentWidthChanged:Qt.callLater(centerClock)
      function reveal(item) {
        var p=item.mapToItem(stage,0,0)
        contentX=Math.max(0,Math.min(Math.max(0,contentWidth-width),p.x<contentX ? p.x : p.x+item.width>contentX+width ? p.x+item.width-width : contentX))
        root.revealFocus(item)
      }
      Item {
        id:stage
        width:root.vertical ? preview.width : Math.max(preview.width,clockText.implicitWidth+2*Math.max(left.implicitWidth,right.implicitWidth)+Style.space(40))
        height:root.vertical ? left.implicitHeight+clockButton.height+right.implicitHeight+Style.space(32) : Style.space(42)
        ClockIndicatorStrip {
          id:left
          elements:root.elements.filter(function(row){return row.side==="left"})
          service:root.service;settings:root.settings;strings:root.strings;bar:root.bar
          vertical:root.vertical;barSize:Style.space(32);barHeight:Style.space(26)
          editing:true;selectedId:root.selectedId
          foreground:Design.text
          x:root.vertical ? (parent.width-width)/2 : clockButton.x-left.columnSpacing-width
          y:root.vertical ? Style.space(4) : (parent.height-height)/2
          onSelected:id=>root.selectedId=id
          onDropped:(id,item,dx,dy)=>root.drop(id,item,dx,dy)
          onRevealFocus:item=>preview.reveal(item)
        }
        FeedbackButton {
          id:clockButton;objectName:"clockElement-clock"
          width:clockText.implicitWidth+2*horizontalPadding;height:clockText.implicitHeight+Style.space(10)
          x:(parent.width-width)/2
          y:root.vertical ? left.y+left.height+left.rowSpacing : (parent.height-height)/2
          selected:root.selectedId==="clock";bordered:selected;focusable:true
          horizontalPadding:Design.gap.small;verticalPadding:0
          Accessible.name:root.strings.t("clock.time")
          onClicked:root.selectedId="clock"
          onActiveFocusChanged:if(activeFocus) {root.selectedId="clock";preview.reveal(this)}
          PlainText {id:clockText;anchors.centerIn:parent;text:root.formatted(root.format);font.family:root.bar ? root.bar.fontFamily : Design.fontFamily;typeRole:"bar";horizontalAlignment:Text.AlignHCenter}
        }
        ClockIndicatorStrip {
          id:right
          elements:root.elements.filter(function(row){return row.side==="right"})
          service:root.service;settings:root.settings;strings:root.strings;bar:root.bar
          vertical:root.vertical;barSize:Style.space(32);barHeight:Style.space(26)
          editing:true;selectedId:root.selectedId
          foreground:Design.text
          x:root.vertical ? (parent.width-width)/2 : clockButton.x+clockButton.width+right.columnSpacing
          y:root.vertical ? clockButton.y+clockButton.height+right.rowSpacing : (parent.height-height)/2
          onSelected:id=>root.selectedId=id
          onDropped:(id,item,dx,dy)=>root.drop(id,item,dx,dy)
          onRevealFocus:item=>preview.reveal(item)
        }
      }
    }
  }
  RowLayout {
    width:parent.width;spacing:Design.gap.small
    layoutDirection:Commons.I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
    height:Math.max(Design.fieldHeight,implicitHeight)
    PlainText {
      Layout.fillWidth:true;Layout.minimumWidth:0
      text:root.selectedRow ? root.elementTitle(root.selectedRow) : root.strings.t("clock.format")
      typeRole:"title";wrapMode:Text.Wrap
    }
    DesignDropdown {
      id:formats;objectName:"clockFormat";Layout.fillWidth:true;Layout.maximumWidth:Style.space(260)
      Accessible.name:root.strings.t("clock.format");visible:root.selectedId==="clock";showLabel:false;value:root.format
      options:Clock.clockFormatRing(root.format,"",Clock.clockFormats(root.vertical)).map(function(format){return {value:format,label:root.formatted(format).replace(/\n/g," ")}})
      onChanged:value=>{root.settingRequested(root.formatKey,value);formats.value=Qt.binding(function(){return root.format})}
      onActiveFocusChanged:if(activeFocus) root.revealFocus(this)
    }
    Row {
      id:actions;spacing:Design.gap.micro
      FeedbackButton {visible:root.selectedId==="clock";iconSize:fontSize;iconText:"…";compact:true;focusable:true;tooltipText:root.strings.t("clock.format");onClicked:{root.customFormatOpen=!root.customFormatOpen;if(root.customFormatOpen) customFormat.forceActiveFocus()}}
      FeedbackButton {objectName:"clockMoveBack";visible:!!root.selectedRow;iconSize:fontSize;iconText:root.vertical ? "↑" : "←";compact:true;focusable:true;tooltipText:root.strings.t("clock.previous");onClicked:root.move(-1)}
      FeedbackButton {objectName:"clockMoveForward";visible:!!root.selectedRow;iconSize:fontSize;iconText:root.vertical ? "↓" : "→";compact:true;focusable:true;tooltipText:root.strings.t("clock.next");onClicked:root.move(1)}
      FeedbackButton {objectName:"clockSwitchSide";visible:!!root.selectedRow;iconSize:fontSize;iconText:"⇄";compact:true;focusable:true;tooltipText:root.strings.t("clock.switchSide");onClicked:root.save(ClockLayout.move(root.elements,root.selectedId,root.side==="left" ? "right" : "left",""))}
      FeedbackButton {objectName:"clockRemove";visible:!!root.selectedRow;iconSize:fontSize;iconText:"×";compact:true;focusable:true;tooltipText:root.strings.t("clock.remove");onClicked:root.remove()}
    }
  }
  DesignTextField {
    id:customFormat;objectName:"clockCustomFormat";width:parent.width
    visible:root.selectedId==="clock" && root.customFormatOpen
    text:root.format.replace(/\n/g,"\\n")
    Accessible.name:root.strings.t("clock.format")
    onEditingFinished:if(text.length>0 && text.length<=160) root.settingRequested(root.formatKey,text.replace(/\\n/g,"\n"))
    onActiveFocusChanged:if(activeFocus) root.revealFocus(this)
    Keys.onEscapePressed:{text=root.format.replace(/\n/g,"\\n");clockButton.forceActiveFocus()}
  }
  Binding {target:customFormat;property:"text";value:root.format.replace(/\n/g,"\\n");when:!customFormat.activeFocus}
  RowLayout {
    width:parent.width;spacing:Design.gap.medium
    layoutDirection:Commons.I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
    PlainText {
      text:root.strings.t("clock.elements");typeRole:"section";wrapMode:Text.Wrap
      Layout.fillWidth:true;Layout.minimumWidth:0
    }
    DesignDropdown {
      id:addMenu;objectName:"clockAdd";Layout.preferredWidth:Math.min(root.width*0.57,Math.max(Style.space(160),addMetrics.advanceWidth(root.strings.t("clock.add"))+Design.gap.spacious))
      showLabel:false;value:"";enabled:root.elements.length<32
      options:[{value:"",label:root.strings.t("clock.add")}].concat(root.entries.filter(function(entry){return !root.elements.some(function(row){return row.id===entry.id})}).map(function(entry){return {value:entry.id,label:entry.title || root.strings.t(entry.titleKey)}})).concat([{value:"separator",label:root.strings.t("clock.separator")},{value:"space",label:root.strings.t("clock.space")}])
      onChanged:value=>{if(value) root.add(value);addMenu.value=""}
      onActiveFocusChanged:if(activeFocus) root.revealFocus(this)
    }
  }
  FontMetrics {id:addMetrics;font.family:Design.fontFamily;font.pixelSize:Design.type.body}
  ClockReorderBoard {id:board;width:parent.width;editor:root;viewport:root.scrollViewport}
  Keys.onPressed:event=>{
    if(board.dragged && event.key===Qt.Key_Escape) {board.cancel();event.accepted=true}
    else if(root.selectedRow && (event.modifiers & Qt.ControlModifier) && [Qt.Key_Left,Qt.Key_Right,Qt.Key_Up,Qt.Key_Down].indexOf(event.key)>=0) {
      root.move(event.key===Qt.Key_Left || event.key===Qt.Key_Up ? -1 : 1);event.accepted=true
    } else if(root.selectedRow && event.key===Qt.Key_Delete) {root.remove();event.accepted=true}
  }
}
