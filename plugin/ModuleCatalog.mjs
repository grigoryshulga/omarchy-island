import downloads from "./modules/downloads/Module.mjs";
import media from "./modules/media/Module.mjs";
import notifications from "./modules/notifications/Module.mjs";
import battery from "./modules/battery/Module.mjs";
import controls from "./modules/controls/Module.mjs";
import overview from "./modules/overview/Module.mjs";
import calendar from "./modules/calendar/Module.mjs";
import weather from "./modules/weather/Module.mjs";
import herdr from "./modules/herdr/Module.mjs";
import codex from "./modules/codex/Module.mjs";
import t3 from "./modules/t3/Module.mjs";
import limits from "./modules/agent-limits/Module.mjs";

// Presentation order is stable across all monitors.
export const definitions = [downloads, media, notifications, battery, controls, overview, calendar, weather, limits, t3, herdr, codex];
export function definition(id) {return definitions.find(entry => entry.id === id) || null}

export function ordered(place) {
  return definitions.slice().sort(function(a,b) {
    return ((a.order || {})[place] || 0)-((b.order || {})[place] || 0);
  });
}

export function pages(){return definitions.filter(function(entry){return !!entry.page}).sort(function(a,b){return a.pageIndex-b.pageIndex})}
