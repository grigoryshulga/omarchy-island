import QtQuick
import "../.." as Island
import "../../Model.js" as Model

Island.ModuleView {
  id:root
  readonly property var sources:backend ? backend.sources : []
  available:(presentation.expanded || presentation.hovering) && !!backend && backend.allowed && sources.length>0
  implicitHeight:content.implicitHeight
  function sync() {Model.syncKeys(sourceKeys,sources.map(function(source){return source.id}))}
  onSourcesChanged:sync()
  Component.onCompleted:sync()
  ListModel {id:sourceKeys}
  Column {
    id:content;width:parent.width;spacing:Island.Design.gap.small
    Island.SectionLink {
      width:parent.width;title:"Herdr";visible:!root.presentation.detail
      feedback:root.presentation.feedback
      onClicked:root.detailsRequested()
    }
    Repeater {
      model:sourceKeys
      Column {
        id:sourceColumn
        required property string entryKey
        readonly property var source:root.sources.find(function(item){return item.id===sourceColumn.entryKey}) || ({label:"",status:"unavailable",rows:[]})
        function sync() {Model.syncKeys(sessionKeys,source.rows.map(function(row){return row.id}))}
        onSourceChanged:sync()
        Component.onCompleted:sync()
        ListModel {id:sessionKeys}
        width:parent.width;spacing:Island.Design.gap.small
        Island.PlainText {
          width:parent.width;visible:sourceColumn.source.status!=="connected" || !sourceColumn.source.rows.length
          text:sourceColumn.source.label+" · "+root.presentation.strings.t("herdr."+(sourceColumn.source.status!=="connected" ? "unavailable" : "empty"))
          typeRole:"caption";color:Island.Design.secondaryText;wrapMode:Text.Wrap
        }
        Repeater {
          model:sessionKeys
          Island.HerdrSessionCard {
            required property string entryKey
            required property int index
            width:parent.width
            row:sourceColumn.source.rows.find(function(item){return item.id===entryKey}) || ({id:entryKey,title:"",source:"",pane:"",status:"unknown"})
            strings:root.presentation.strings
            visible:root.presentation.detail || index<3
            compactOverview:!root.presentation.detail
            expanded:root.presentation.expanded
            active:root.visible && root.available && root.presentation.active
            feedback:root.presentation.feedback
            onOverviewDetailsRequested:root.detailsRequested()
            onExpandRequested:root.expandRequested()
          }
        }
      }
    }
  }
}
