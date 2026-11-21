export const modes = ["timer", "pomodoro", "stopwatch"];
const minute = 60000;
const day = 24 * 60 * minute;

export function initial() {
  return {status: "idle", elapsed: 0, since: 0, duration: 5 * minute, step: 0};
}

export function restore(value) {
  const state = initial();
  if (!value || !["idle", "running", "paused", "done"].includes(value.status)) return state;
  if (!Number.isSafeInteger(value.elapsed) || value.elapsed < 0 ||
      !Number.isSafeInteger(value.since) || value.since < 0 ||
      (value.status === "running" && !value.since)) return state;
  if (!Number.isInteger(value.duration) || value.duration < 1000 || value.duration > day ||
      !Number.isInteger(value.step) || value.step < 0 || value.step > 7) return state;
  return Object.assign(state, {status:value.status, elapsed:value.elapsed, since:value.since,
                               duration:value.duration, step:value.step});
}

export function phase(step) {
  if (step % 2 === 0) return "focus";
  return step === 7 ? "longBreak" : "shortBreak";
}
export function limit(mode, state) {
  if (mode === "stopwatch") return Infinity;
  if (mode === "timer") return state.duration;
  return ({focus:25, shortBreak:5, longBreak:15})[phase(state.step)] * minute;
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
// Bare numbers are minutes. The colon form also supports sub-minute timers.
export function parseDuration(text) {
  const match = /^(\d{1,4})(?::([0-5]\d))?$/.exec(String(text).trim());
  const ms = match ? Number(match[1])*minute + Number(match[2] || 0)*1000 : 0;
  return ms >= 1000 && ms <= day ? ms : 0;
}
export function durationInput(ms) {
  return Math.floor(ms/minute) + ":" + String(Math.floor(ms/1000)%60).padStart(2,"0");
}
export function start(state, now) {
  return Object.assign({}, state, {status:"running", since:now, elapsed:state.status === "paused" ? state.elapsed : 0});
}
export function pause(state, now) {
  return Object.assign({}, state, {status:"paused", since:0, elapsed:elapsed(state,now)});
}
export function complete(mode, state) {
  if (mode === "pomodoro") return Object.assign(initial(), {step:(state.step+1)%8});
  return Object.assign({}, state, {status:"done", since:0, elapsed:state.duration});
}
