export default {
  id:"calendar",titleKey:"calendar.open",state:"modules/calendar/State.qml",page:"modules/calendar/Page.qml",
  enabledSetting:"calendarEnabled",pageIndex:2,tabObjectName:"calendarOpen",
  defaults:{calendarEnabled:true,calendarWeekStart:"locale"},
  choices:{calendarWeekStart:["locale","monday","sunday"]},
  groups:[{id:"calendar",moduleId:"calendar",view:"modules/calendar/Settings.qml",
    rows:[{key:"calendarEnabled"},{key:"calendarWeekStart",type:"choice",dependsOn:"calendarEnabled"}]}]
};
