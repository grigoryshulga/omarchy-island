// A bounded, shared memory of audio attacks, in visual-clock seconds.
// This is an envelope onset heuristic, not a tempo/beat detector.
function empty() { return {previous: 0, times: [-10, -10, -10, -10], strengths: [0, 0, 0, 0]} }

function sample(state, time, level, bass) {
    var energy = Math.max(0, Math.min(1, level * 0.6 + bass * 0.4));
    var times = state.times.slice(), strengths = state.strengths.slice();
    var rise = energy - state.previous;
    if (energy > 0.06 && rise > 0.035 && time - times[0] >= 0.28) {
        times.unshift(time); times.length = 4;
        strengths.unshift(Math.min(1, 0.25 + rise * 2.5)); strengths.length = 4;
    }
    return {previous: energy, times: times, strengths: strengths};
}

if (typeof module !== "undefined") module.exports = {empty: empty, sample: sample};
