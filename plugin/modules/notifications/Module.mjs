export default {
  id:"notifications",titleKey:"notifications.active",state:"NotificationState.qml",order:{overview:40},
  defaults:{notificationStyle:"card"},choices:{notificationStyle:["card","bar"]},
  settingsSection:"alerts",groups:[{id:"notifications",rows:[{key:"notificationStyle",type:"choice"}]}],
  overviewSizes:["minimal", "compact", "large"],
  overview:"modules/notifications/Overview.qml",usesHost:true
};
