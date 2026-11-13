export default {
  id: "example",
  titleKey: "example.title",
  state: "modules/example/State.qml",
  overview: "modules/example/Overview.qml",
  indicator: "modules/example/Indicator.qml",
  defaults: {exampleEnabled: false},
  groups: [{id: "example", rows: [{key: "exampleEnabled"}]}]
};
