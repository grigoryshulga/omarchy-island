export const modes = ["timer", "pomodoro", "stopwatch"];
// Material Design glyphs in Omarchy's Nerd Font (timer-sand, target, timer-outline).
export const glyphs = {timer:"󰔟", pomodoro:"󰓾", stopwatch:"󰔛", play:"󰐊", pause:"󰏤", reset:"󰦛", world:"󰇧"};
const minute = 60000;
const day = 24 * 60 * minute;

export function initial() {
  return {status: "idle", elapsed: 0, since: 0, duration: 5 * minute, step: 0};
}

export const defaultPlan = {rounds:4, focus:25, shortBreak:5, longBreak:15};
export function validSetting(key, value) {
  return Object.prototype.hasOwnProperty.call(defaultPlan,key) && Number.isInteger(value)
      && value >= 1 && value <= (key === "rounds" ? 16 : 1440);
}
export function restorePlan(value) {
  return value && Object.keys(defaultPlan).every(key => validSetting(key,value[key]))
      ? {rounds:value.rounds, focus:value.focus, shortBreak:value.shortBreak, longBreak:value.longBreak} : defaultPlan;
}
export function pomodoro(plan) { return Object.assign(initial(), {plan:plan}); }

export function restore(value, cyclePlan) {
  const state = cyclePlan ? pomodoro(restorePlan(value && value.plan || cyclePlan)) : initial();
  if (!value || !["idle", "running", "paused", "done"].includes(value.status)) return state;
  if (!Number.isSafeInteger(value.elapsed) || value.elapsed < 0 ||
      !Number.isSafeInteger(value.since) || value.since < 0 ||
      (value.status === "running" && !value.since)) return state;
  if (!Number.isInteger(value.duration) || value.duration < 1000 || value.duration > day ||
      !Number.isInteger(value.step) || value.step < 0 || value.step >= (state.plan ? state.plan.rounds*2 : 8)) return state;
  return Object.assign(state, {status:value.status, elapsed:value.elapsed, since:value.since,
                               duration:value.duration, step:value.step});
}

export function phase(state) {
  if (state.step % 2 === 0) return "focus";
  return state.step === (state.plan || defaultPlan).rounds*2-1 ? "longBreak" : "shortBreak";
}
export function limit(mode, state) {
  if (mode === "stopwatch") return Infinity;
  if (mode === "timer") return state.duration;
  return (state.plan || defaultPlan)[phase(state)] * minute;
}
export function elapsed(state, now) {
  return state.elapsed + (state.status === "running" ? Math.max(0, now - state.since) : 0);
}
export function reading(mode, state, now) {
  const spent = elapsed(state, now);
  return mode === "stopwatch" ? Math.floor(spent/1000) : Math.ceil(Math.max(0,limit(mode,state)-spent)/1000);
}
export function format(seconds, digit) {
  const hours = Math.floor(seconds/3600);
  let text = (hours ? hours + ":" : "") + String(Math.floor(seconds/60)%60).padStart(2,"0")
             + ":" + String(seconds%60).padStart(2,"0");
  return digit ? text.replace(/\d/g, c => digit(Number(c))) : text;
}
export function parseDuration(text, zeroDigit = "0") {
  const zero = zeroDigit.charCodeAt(0);
  const normalized = Array.from(String(text).trim(), ch => {
    const digit = ch.charCodeAt(0) - zero;
    return digit >= 0 && digit <= 9 ? String(digit) : ch;
  }).join("");
  const match = /^(\d{2}):([0-5]\d):([0-5]\d)$/.exec(normalized);
  const ms = match ? (Number(match[1])*60 + Number(match[2]))*minute + Number(match[3])*1000 : 0;
  return ms >= 1000 && ms <= day ? ms : 0;
}
export function durationInput(ms, digit) {
  const parts = [Math.floor(ms/(60*minute)), Math.floor(ms/minute)%60, Math.floor(ms/1000)%60];
  const text = parts.map(value => String(value).padStart(2,"0")).join(":");
  return digit ? text.replace(/\d/g, ch => digit(Number(ch))) : text;
}
export function start(state, now) {
  return Object.assign({}, state, {status:"running", since:now, elapsed:state.status === "paused" ? state.elapsed : 0});
}
export function pause(state, now) {
  return Object.assign({}, state, {status:"paused", since:0, elapsed:elapsed(state,now)});
}
export function complete(mode, state, nextPlan) {
  if (mode === "pomodoro") {
    const step = state.step+1;
    if (step === state.plan.rounds*2) return pomodoro(nextPlan);
    return Object.assign(pomodoro(state.plan), {step});
  }
  return Object.assign({}, state, {status:"done", since:0, elapsed:state.duration});
}
