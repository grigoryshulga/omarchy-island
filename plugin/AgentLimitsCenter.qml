import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import "AgentLimitsModel.js" as Model
import "vendor/agent-limits/Model.js" as Usage

Column {
  id:root
  required property var backend
  required property var strings
  property var feedback:null
  property string tab:"limits"
  property string range:"week"
  property var providers:backend ? backend.cache.providers : []
  property var windows:backend ? backend.rows : []
  property var series:range==="today" ? Usage.hourly(backend ? backend.cache : {providers:[]},tab==="cost" ? "cost" : "tokens") : Usage.windowSeries(backend ? backend.cache : {providers:[]},tab==="cost" ? "cost" : "tokens",range)
  property real maximum:Math.max.apply(null,[1].concat(series.map(function(d){return d.value})))
  ListModel {id:windowItems}
  function syncWindows() {
    var ids=windows.map(function(r){return r.id})
    for(var i=windowItems.count-1;i>=0;i--) if(ids.indexOf(windowItems.get(i).windowId)<0) windowItems.remove(i)
    ids.forEach(function(id){for(var j=0;j<windowItems.count;j++) if(windowItems.get(j).windowId===id) return;windowItems.append({windowId:id})})
  }
  onWindowsChanged:syncWindows()
  Component.onCompleted:syncWindows()
  signal settingRequested(string key,var value)
  spacing:Design.gap.small
  onVisibleChanged:if(visible && backend) backend.loadCatalog()
  RowLayout {
    width:parent.width;spacing:Design.gap.micro
    Repeater {
      model:["limits","usage","cost","providers"]
      TabButton {required property string modelData;Layout.fillWidth:true;label:root.strings.t("limits.tab."+modelData);tabActive:root.tab===modelData;focusable:true;feedback:root.feedback;onClicked:root.tab=modelData}
    }
    FeedbackButton {text:"󰑐";tooltipText:root.strings.t("limits.refresh");compact:true;focusable:true;enabled:root.backend && !root.backend.busy;onClicked:root.backend.refresh()}
  }
  PlainText {
    width:parent.width;typeRole:"caption";color:Design.secondaryText;wrapMode:Text.Wrap
    text:root.strings.t(root.backend && root.backend.busy ? "limits.loading" : root.backend && root.backend.error ? "limits.error" : "limits.shared")
  }
  Controls.ScrollView {
    id:viewport
    objectName:"limitsCenterScroll"
    width:parent.width;height:Math.min(content.implicitHeight,Style.space(300));clip:true;contentWidth:availableWidth
    Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
    Column {
      id:content;width:viewport.availableWidth;spacing:Design.gap.small
      Column {
        visible:root.tab==="limits";width:parent.width;spacing:Design.gap.small
        Repeater {
          model:windowItems
          Column {
            id:entry
            required property string windowId
            readonly property var modelData:root.windows.find(function(r){return r.id===windowId}) || ({id:windowId,name:"",label:"",remaining:null})
            width:parent.width;spacing:Design.gap.micro
            AgentLimitRow {width:parent.width;row:entry.modelData;strings:root.strings;feedback:root.feedback;now:root.backend.now;interactive:true;pinned:root.backend.pins.indexOf(row.id)>=0;onPinRequested:id=>root.settingRequested("agentLimitsPins",Model.toggle(root.backend.pins,id))}
            Row {
              visible:root.backend.pins.indexOf(entry.modelData.id)>=0
              FeedbackButton {text:"↑";tooltipText:root.strings.t("limits.moveUp");compact:true;focusable:true;enabled:root.backend.pins.indexOf(entry.modelData.id)>0;onClicked:{var pins=root.backend.pins.slice(),i=pins.indexOf(entry.modelData.id),a=pins[i-1];pins[i-1]=pins[i];pins[i]=a;root.settingRequested("agentLimitsPins",pins)}}
              FeedbackButton {text:"↓";tooltipText:root.strings.t("limits.moveDown");compact:true;focusable:true;enabled:root.backend.pins.indexOf(entry.modelData.id)<root.backend.pins.length-1;onClicked:{var pins=root.backend.pins.slice(),i=pins.indexOf(entry.modelData.id),a=pins[i+1];pins[i+1]=pins[i];pins[i]=a;root.settingRequested("agentLimitsPins",pins)}}
            }
          }
        }
        Repeater {
          model:root.providers
          PlainText {
            required property var modelData
            width:parent.width;typeRole:"caption";wrapMode:Text.Wrap;color:Design.secondaryText
            text:modelData.name+" · "+((modelData.balance || []).length ? (modelData.balance || []).map(function(b){return String(b.currency)+" "+String(b.total)}).join(" · ") : (modelData.limits || []).length ? String(modelData.plan || "") : root.strings.t("limits.unavailable"))+(modelData.status==="error" ? " · "+root.strings.t("limits.providerError") : modelData.stale ? " · "+root.strings.t("limits.cached") : "")
          }
        }
        PlainText {visible:!root.windows.length;width:parent.width;wrapMode:Text.Wrap;typeRole:"caption";text:root.strings.t("limits.noWindows")}
      }
      Column {
        visible:root.tab==="usage" || root.tab==="cost";width:parent.width;spacing:Design.gap.small
        Row {
          Repeater {model:["today","week","month"];TabButton {required property string modelData;label:root.strings.t("limits.range."+modelData);tabActive:root.range===modelData;focusable:true;onClicked:root.range=modelData}}
        }
        PlainText {width:parent.width;wrapMode:Text.Wrap;typeRole:"caption";color:Design.secondaryText;text:root.strings.t(root.tab==="cost" ? "limits.estimate" : "limits.localUsage")}
        Row {
          width:parent.width;height:Style.space(70);spacing:Design.gap.micro
          Repeater {
            model:root.series
            Rectangle {
              required property var modelData
              width:Math.max(1,(parent.width-(root.series.length-1)*parent.spacing)/Math.max(1,root.series.length))
              height:Math.max(1,parent.height*modelData.value/root.maximum)
              anchors.bottom:parent.bottom;color:Design.accent;radius:Math.min(Style.cornerRadius,Style.space(2))
            }
          }
        }
        PlainText {width:parent.width;typeRole:"caption";color:Design.secondaryText;text:root.range==="today" ? Commons.I18n.formatNumber(0)+":00 — "+Commons.I18n.formatNumber(23)+":00" : root.series.length ? new Date(root.series[0].date+"T12:00:00").toLocaleDateString(Qt.locale(Commons.I18n.formatLocale),"d MMM")+" — "+new Date(root.series[root.series.length-1].date+"T12:00:00").toLocaleDateString(Qt.locale(Commons.I18n.formatLocale),"d MMM") : root.strings.t("limits.noUsage")}
        PlainText {
          visible:root.range==="today" && Usage.providersWithoutHours(root.backend ? root.backend.cache : {providers:[]}).length>0
          width:parent.width;wrapMode:Text.Wrap;typeRole:"caption";color:Design.secondaryText
          text:root.strings.t("limits.noHourly").arg(Usage.providersWithoutHours(root.backend ? root.backend.cache : {providers:[]}).join(", "))
        }
        Repeater {
          model:root.providers
          Column {
            id:stats
            required property var modelData
            property var totals:Model.metrics(modelData,root.range)
            width:parent.width;spacing:Design.gap.tight
            PlainText {
              width:parent.width;wrapMode:Text.Wrap;typeRole:"title"
              objectName:"agentProviderTotals-"+stats.modelData.id
              text:stats.modelData.name+" · "+(!stats.totals.available ? "—" : root.tab==="cost" ? "$"+Commons.I18n.formatNumber(stats.totals.cost,2) : root.strings.t("limits.tokens").arg(Commons.I18n.formatNumber(stats.totals.tokens)))
            }
            PlainText {
              width:parent.width;wrapMode:Text.Wrap;typeRole:"caption";color:Design.secondaryText
              text:!stats.totals.available ? root.strings.t("limits.noUsage") : (root.tab==="cost" && stats.totals.unpriced ? root.strings.t("limits.unpriced")+" · " : "")+root.strings.t("limits.requests").arg(Commons.I18n.formatNumber(stats.totals.requests))
            }
            // Model costs in the upstream snapshot are all-time aggregates.
            Repeater {
              model:(stats.modelData.models || []).slice(0,20)
              PlainText {required property var modelData;width:parent.width;wrapMode:Text.Wrap;typeRole:"caption";color:Design.secondaryText;text:String(modelData.model || modelData.name || "")+" · "+root.strings.t("limits.allTime")+" · "+(root.tab==="cost" ? modelData.priced ? "$"+Commons.I18n.formatNumber(Number(modelData.cost || 0),2) : root.strings.t("limits.unpriced") : root.strings.t("limits.tokens").arg(Commons.I18n.formatNumber(Number(modelData.tokens || 0))))}
            }
          }
        }
      }
      AgentLimitsProviders {visible:root.tab==="providers";width:parent.width;backend:root.backend;strings:root.strings;feedback:root.feedback}
    }
  }
}
