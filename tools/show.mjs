import { loadLevel, solve, initialState, step, actionText } from '../web/js/engine.js';
import { LEVELS } from './levels.src.mjs';
const i = +process.argv[2] - 1;
const L = loadLevel(JSON.parse(JSON.stringify(LEVELS[i])));
const r = solve(L, 3000000);
console.log(r.solved, r.states);
if (r.solved) { let s = initialState(L); for (const a of r.path) { s = step(L, s, a).state; console.log(actionText(a).padEnd(28), 'p=' + s.p, 'c=' + JSON.stringify(s.crates), 'b=' + JSON.stringify(s.balls.map(b=>b&&b.p)), 'lv=' + s.levers, 'rot=' + s.rots, 'sl=' + s.slides, 'br=' + s.bridges, 'v=' + s.view); } }
