// Use only connected sources. Return the original row so opening the
// indicator can target the same session, file or selected MPRIS player.
export function current(service) {
  if (!service) return null;

  const t3 = service.t3;
  if (t3 && t3.connected) {
    const pending = t3.rows.filter(row => !!row.requestId);
    if (pending.length) return {kind:"t3", count:pending.length, row:pending[0]};
  }

  // Watcher updates can change enumeration order. Keep the oldest active
  // file until it completes; its path breaks ties within a single scan.
  const files = (service.downloads || []).filter(row => row.active);
  if (files.length) {
    const first = files.reduce((a, b) =>
      a.ts < b.ts || (a.ts === b.ts && a.downloadPath < b.downloadPath) ? a : b);
    return {kind:"downloads", count:files.length, row:first};
  }

  if (service.playing && service.player) {
    return {kind:"media", count:1, row:service.player};
  }
  return null;
}

export function glyph(activity) {
  if (!activity) return "";
  return {t3:"󰋗", downloads:"󰇚", media:"󰎆"}[activity.kind];
}
