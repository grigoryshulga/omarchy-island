import {valid} from "../../OverviewModel.mjs";
export default {id:"overview",titleKey:"tabs.overview",page:"modules/overview/Page.qml",tab:"modules/overview/Tab.qml",pageIndex:1,tabObjectName:"islandTabOverview",defaults:{overviewEnabled:true,overviewLayout:[]},validators:{overviewLayout:valid,overviewEnabled:function(value){return value===true}}};
