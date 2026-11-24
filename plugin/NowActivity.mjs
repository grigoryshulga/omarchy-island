import * as Time from "./modules/timers/Time.mjs";

export function activities(service) {
  if (!service) return [];
  const result = [];

  const t3 = service.t3;
  if (t3 && t3.connected) {
    for (const row of t3.rows) {
      if (row.requestId) result.push({id:JSON.stringify(["t3",row.id,row.requestId]), kind:"t3", row});
    }
  }

  const timers = service.modules && service.modules.timers;
  if (timers) {
    for (const mode of Time.modes) {
      const state = timers.records[mode];
      if (state && state.status === "running") {
        result.push({id:"timers:"+mode, kind:"timers", row:{
          mode, label:mode === "pomodoro" ? Time.phase(state) : mode,
          seconds:Time.reading(mode,state,timers.now)
        }});
      }
    }
  }

  // Watcher updates can change enumeration order. Keep the oldest active
  // file until it completes; its path breaks ties within a single scan.
  const files = (service.downloads || []).filter(row => row.active)
    .sort((a,b) => a.ts-b.ts || (a.downloadPath < b.downloadPath ? -1 : a.downloadPath > b.downloadPath ? 1 : 0));
  for (const row of files) {
    result.push({id:"downloads:"+(row.key || row.downloadPath), kind:"downloads", row});
  }

  return result;
}

export function current(service) {
  return activities(service)[0] || null;
}

export function target(activity) {
  if (activity.kind === "t3") return {sessionId:activity.row.id, requestId:activity.row.requestId};
  if (activity.kind === "timers") return {mode:activity.row.mode};
  if (activity.kind === "downloads") {
    return {downloadKey:activity.row.key, downloadName:activity.row.filename};
  }
  return {};
}

export function glyph(activity) {
  if (!activity) return "";
  if (activity.kind === "timers") return Time.glyphs[activity.row.mode];
  return {t3:"󰋗", downloads:"󰇚"}[activity.kind];
}
