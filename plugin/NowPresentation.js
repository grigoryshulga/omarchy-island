.pragma library
.import "Downloads.js" as Downloads
.import "modules/timers/Time.mjs" as Time

function describe(activity, strings, formatNumber) {
  if (!activity) return {label:"", title:"", detail:""}
  var row = activity.row
  if (activity.kind === "t3") {
    if (activity.count > 1) {
      var count = strings.t("now.requests").arg(formatNumber(activity.count))
      return {label:count, title:count, detail:"T3 Code"}
    }
    var question = row.requestKind === "user_input"
    var label = strings.t(question ? "now.answer" : "now.action")
    var questions = row.request && row.request.questions || []
    var first = question && questions.length ? questions[0].text : ""
    return {label:label, title:label, detail:[row.project, first || row.title].filter(Boolean).join(" · ")}
  }
  if (activity.kind === "timers") {
    var time = Time.format(row.seconds,formatNumber)
    return {label:time, title:strings.t("timers."+row.label), detail:time}
  }
  if (activity.kind === "downloads") {
    var bytes = Downloads.sizeText(row.downloadedBytes,formatNumber)
    return {label:bytes, title:strings.t("downloads.downloading"), detail:[row.filename, bytes].join(" · ")}
  }
  var title = row.trackTitle || strings.t("now.playing")
  return {label:title, title:title, detail:row.trackArtist || row.identity || strings.t("media.title")}
}
