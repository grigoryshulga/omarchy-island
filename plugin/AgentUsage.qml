import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import "AgentUsageModel.js" as Usage

Column {
  id: root
  required property var backend
  required property var strings
  property var feedback: null
  property real availableHeight: 450
  property string range: "week"
  property string metric: "tokens"
  property string providerId: ""
  property string selectedPeriod: ""
  readonly property var providers: backend ? backend.cache.providers : []
  readonly property var overview: Usage.analyze(backend ? backend.cache : {}, range, providerId, "", backend ? backend.now : Date.now())
  readonly property var report: selectedPeriod ? Usage.analyze(backend ? backend.cache : {}, range, providerId, selectedPeriod, backend ? backend.now : Date.now()) : overview
  readonly property var series: overview.series
  readonly property real maximum: (Math.max.apply(null,[0].concat(series.map(function(p){return p.totals[root.metric]}))) || 1)
  readonly property var models: report.models.slice().sort(function(a,b){return b.totals[root.metric]-a.totals[root.metric]}).filter(function(m){return m.totals[root.metric]>0})
  onRangeChanged: selectedPeriod = ""
  onSeriesChanged: if (selectedPeriod && !series.some(function(point){return point.key===selectedPeriod})) selectedPeriod=""
  onProvidersChanged: if (providerId && !providers.some(function(p){return p.id===providerId})) providerId=""
  spacing: Design.gap.small
  function value(amount) { return metric==="cost" ? "$"+Commons.I18n.formatNumber(amount,2) : Usage.compact(amount,strings,Commons.I18n.formatNumber) }
  function exact(amount) { return metric==="cost" ? "$"+Commons.I18n.formatNumber(amount,4) : strings.t("limits.tokens").arg(Commons.I18n.formatNumber(amount)) }
  function period(key) { return range==="today" ? Commons.I18n.formatNumber(Number(key))+":00" : new Date(key+"T12:00:00").toLocaleDateString(Qt.locale(Commons.I18n.formatLocale),"d MMM") }
  function tint(id) {
    var index=providers.findIndex(function(p){return p.id===id})
    return [Design.accent,Design.info,Design.success,Design.warning][Math.max(0,index)%4]
  }
  Column {
    id: filters
    width: parent.width; spacing: Design.gap.tight
    RowLayout {
      width: parent.width
      Repeater {
        model: ["today","week","month"]
        TabButton { required property string modelData; Layout.fillWidth:true; label:root.strings.t("limits.range."+modelData); tabActive:root.range===modelData; focusable:true; onClicked:root.range=modelData }
      }
      FeedbackButton {
        text:"ⓘ"; compact:true; focusable:true
        tooltipText:root.strings.t(root.metric==="cost" ? "limits.estimate" : "limits.localUsage")
        Accessible.description:tooltipText
      }
    }
    RowLayout {
      width:parent.width
      Repeater {
        model:["tokens","cost"]
        TabButton { required property string modelData; Layout.fillWidth:true; label:root.strings.t("limits.metric."+modelData); tabActive:root.metric===modelData; focusable:true; onClicked:root.metric=modelData }
      }
    }
    Controls.ScrollView {
      id: providerScroll
      width: parent.width; height: providerChoices.implicitHeight
      contentWidth: providerChoices.implicitWidth
      clip:true
      Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
      Controls.ScrollBar.vertical.policy:Controls.ScrollBar.AlwaysOff
      Row {
        id:providerChoices;spacing:Design.gap.tight
        Repeater {
          model:[{id:"",name:root.strings.t("limits.allProviders")}].concat(root.providers)
          FeedbackButton {
            required property var modelData
            text:modelData.name;compact:true;focusable:true;selected:root.providerId===modelData.id
            onClicked:root.providerId=modelData.id
            onActiveFocusChanged:if(activeFocus) providerScroll.contentItem.contentX=Math.max(0,Math.min(x,providerScroll.contentWidth-providerScroll.width))
          }
        }
      }
    }
  }
  Controls.ScrollView {
    objectName:"agentUsageScroll"
    width:parent.width
    height:Math.max(80,root.availableHeight-filters.height-root.spacing)
    clip:true;contentWidth:availableWidth
    Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
    Controls.ScrollBar.vertical.policy:Controls.ScrollBar.AlwaysOff
    Column {
      width:parent.width;spacing:Design.gap.medium
      RowLayout {
        width:parent.width
        ColumnLayout {
          Layout.fillWidth:true
          FeedbackButton {
            objectName:"agentUsageTotal";Layout.fillWidth:true
            fontSize:Design.type.metric;leftAlign:true;horizontalPadding:0;verticalPadding:0
            borderSpec:Border.none();color:"transparent";focusable:true
            text:root.report.available ? root.value(root.report.total[root.metric]) : "—"
            tooltipText:root.exact(root.report.total[root.metric])
          }
          PlainText {Layout.fillWidth:true;typeRole:"caption";color:Design.secondaryText;wrapMode:Text.Wrap;text:(root.selectedPeriod ? root.period(root.selectedPeriod) : root.strings.t("limits.range."+root.range))+" · "+root.strings.t("limits.requests").arg(Commons.I18n.formatNumber(root.report.total.requests))}
        }
        FeedbackButton {visible:root.selectedPeriod!=="";text:"×";tooltipText:root.strings.t("limits.clearPeriod");compact:true;focusable:true;onClicked:root.selectedPeriod=""}
      }
      PlainText {visible:root.metric==="cost" && root.report.total.unpricedTokens>0;width:parent.width;wrapMode:Text.Wrap;typeRole:"caption";color:Design.warning;text:root.strings.t("limits.unpriced")}
      RowLayout {
        width:parent.width;height:Style.space(120);spacing:Design.gap.small
        ColumnLayout {
          Layout.fillHeight:true
          PlainText {typeRole:"caption";color:Design.secondaryText;text:root.value(root.maximum)}
          Item {Layout.fillHeight:true}
          PlainText {typeRole:"caption";color:Design.secondaryText;text:root.value(root.maximum/2)}
          Item {Layout.fillHeight:true}
          PlainText {typeRole:"caption";color:Design.secondaryText;text:Commons.I18n.formatNumber(0)}
        }
        Row {
          Layout.fillWidth:true;Layout.fillHeight:true;spacing:Design.gap.micro
          Repeater {
            model:root.series.length
            Item {
              id:bar
              required property int index
              readonly property var modelData: root.series[index]
              width:Math.max(1,(parent.width-(root.series.length-1)*parent.spacing)/root.series.length)
              height:parent.height
              Column {
                anchors.bottom:parent.bottom;width:parent.width
                Repeater {
                  model:bar.modelData.parts
                  Rectangle {
                    required property var modelData
                    width:bar.width;height:bar.height*modelData.totals[root.metric]/root.maximum
                    color:root.providerId ? Design.accent : root.tint(modelData.id)
                    opacity:root.selectedPeriod && root.selectedPeriod!==bar.modelData.key ? 0.35 : 1
                  }
                }
              }
              FeedbackButton {
                objectName:"usageBucket-"+bar.modelData.key
                anchors.fill:parent
                horizontalPadding:0;verticalPadding:0
                color:"transparent";borderSpec:Border.none()
                focusable:true;selected:root.selectedPeriod===bar.modelData.key
                tooltipText:root.period(bar.modelData.key)+" · "+root.exact(bar.modelData.totals[root.metric])
                onClicked:root.selectedPeriod=root.selectedPeriod===bar.modelData.key ? "" : bar.modelData.key
              }
            }
          }
        }
      }
      RowLayout {
        width:parent.width
        PlainText {Layout.fillWidth:true;typeRole:"caption";color:Design.secondaryText;text:root.period(root.series[0].key)}
        PlainText {typeRole:"caption";color:Design.secondaryText;text:root.period(root.series[root.series.length-1].key)}
      }
      PlainText {visible:root.report.partialHours.length>0;width:parent.width;wrapMode:Text.Wrap;typeRole:"caption";color:Design.warning;text:root.strings.t("limits.noHourly").arg(root.report.partialHours.join(", "))}
      Repeater {
        model:root.report.providers
        RowLayout {
          required property var modelData
          width:parent.width
          AgentProviderIcon {providerId:modelData.id}
          Rectangle {visible:!root.providerId;width:Style.space(6);height:width;color:root.tint(modelData.id);radius:Math.min(Style.cornerRadius,width/2)}
          PlainText {Layout.fillWidth:true;Layout.minimumWidth:0;typeRole:"label";text:modelData.name}
          PlainText {objectName:"agentProviderTotals-"+modelData.id;typeRole:"caption";text:modelData.available ? root.value(modelData.totals[root.metric]) : root.strings.t("limits.noUsage")}
        }
      }
      Repeater {
        model:root.models
        Column {
          required property var modelData
          width:parent.width;spacing:Design.gap.tight
          RowLayout {
            width:parent.width
            PlainText {Layout.fillWidth:true;Layout.minimumWidth:0;text:modelData.name;typeRole:"label"}
            PlainText {typeRole:"caption";text:root.value(modelData.totals[root.metric])+" · "+Commons.I18n.formatNumber(root.report.total[root.metric]>0 ? 100*modelData.totals[root.metric]/root.report.total[root.metric] : 0,1)+"%"}
          }
          BrailleProgress {width:parent.width;value:root.report.total[root.metric]>0 ? modelData.totals[root.metric]/root.report.total[root.metric] : 0;accent:root.providerId ? Design.accent : root.tint(modelData.providerId)}
        }
      }
      PlainText {visible:root.report.unattributed[root.metric]>0;width:parent.width;wrapMode:Text.Wrap;typeRole:"caption";color:Design.secondaryText;text:root.strings.t("limits.unattributed").arg(root.value(root.report.unattributed[root.metric]))}
    }
  }
}
