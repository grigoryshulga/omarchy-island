import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons as Commons
import "CalendarEvents.js" as Model

ColumnLayout {
  id:root
  required property var strings
  required property var subscriptions
  property string selectedKey:""
  property int year:new Date().getFullYear()
  readonly property var rows:subscriptions ? Model.onDay(subscriptions.eventsForYear(year),selectedKey) : []
  readonly property var locale:Qt.locale(Commons.I18n.formatLocale)
  spacing:Design.gap.small
  function timeLabel(event) {
    if(event.allDay) return strings.t("ics.allDay")
    var start=new Date(event.start*1000),end=new Date(event.end*1000)
    var format=event.startDay!==event.endDay ? "d MMM HH:mm" : "HH:mm"
    return start.toLocaleString(locale,format)+(event.end>event.start ? " – "+end.toLocaleString(locale,format) : "")
  }
  RowLayout {
    Layout.fillWidth:true
    SectionHeading {Layout.fillWidth:true;title:root.strings.t("ics.events");detail:root.selectedKey ? new Date(root.selectedKey+"T12:00:00").toLocaleDateString(root.locale,"d MMM") : ""}
    T3Spinner {visible:(!!root.subscriptions && root.subscriptions.busy);active:visible}
  }
  PlainText {visible:!!root.subscriptions && (!!root.subscriptions.error || root.subscriptions.sources.some(function(s){return s.enabled && s.stale}));Layout.fillWidth:true;text:root.strings.t("ics.stale");typeRole:"caption";color:Design.secondaryText;wrapMode:Text.Wrap}
  PlainText {visible:!root.rows.length;Layout.fillWidth:true;text:root.strings.t((!!root.subscriptions && root.subscriptions.busy) ? "ics.loading" : "ics.empty");typeRole:"caption";color:Design.secondaryText;wrapMode:Text.Wrap}
  Controls.ScrollView {
    id:scroll;Layout.fillWidth:true;visible:root.rows.length>0
    implicitHeight:Math.min(list.implicitHeight,Design.fieldHeight*5)
    clip:true;contentWidth:availableWidth
    Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
    Column {
      id:list;width:scroll.availableWidth;spacing:Design.gap.small
      Repeater {
        model:root.rows.slice(0,100)
        Surface {
          required property var modelData
          width:list.width;implicitHeight:content.implicitHeight+Design.gap.medium*2
          ColumnLayout {
            id:content;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:Design.gap.medium;spacing:Design.gap.tight
            RowLayout {
              Layout.fillWidth:true;spacing:Design.gap.small
              PlainText {Layout.fillWidth:true;Layout.minimumWidth:0;text:root.timeLabel(modelData);typeRole:"caption";color:Design.accent;wrapMode:Text.Wrap}
              PlainText {Layout.maximumWidth:list.width/2;text:modelData.sourceName;typeRole:"caption";color:Design.secondaryText}
            }
            PlainText {objectName:"calendarEvent-"+modelData.id;Layout.fillWidth:true;text:modelData.title || root.strings.t("ics.untitled");typeRole:"title";wrapMode:Text.Wrap}
            PlainText {visible:!!modelData.location;Layout.fillWidth:true;text:modelData.location;typeRole:"caption";color:Design.secondaryText;wrapMode:Text.Wrap}
          }
        }
      }
    }
  }
  PlainText {visible:root.rows.length>100;text:root.strings.t("ics.more").arg(Commons.I18n.formatNumber(root.rows.length-100));typeRole:"caption";color:Design.secondaryText}
}
