// tools/check-sim-purity.ts — CI gate: the sim must stay I/O-free, clock-injected,
// and seed-deterministic. Fails if any forbidden token appears under sim/** or
// shared/** (paths relative to this server package). Run via `npm run lint:purity`.
//
// This tool itself is NOT part of the sim; it may use fs/Date freely.
// Ported from SideQuestAppV2 tools/check-sim-purity.ts (roots re-based onto the
// self-contained server package).
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOTS = ['sim', 'shared'];

// Forbidden: non-deterministic time/randomness + node I/O imports in the sim core.
const FORBIDDEN: { re: RegExp; why: string }[] = [
  { re: /\bDate\.now\s*\(/, why: 'Date.now — inject a clock instead' },
  { re: /\bnew\s+Date\b/, why: 'new Date — inject a clock instead' },
  { re: /\bMath\.random\s*\(/, why: 'Math.random — use shared/rng.ts' },
  { re: /\bperformance\.now\s*\(/, why: 'performance.now — inject a clock instead' },
  { re: /from\s+['"]node:(fs|http|https|net|dgram|ws)['"]/, why: 'node I/O import in sim' },
  { re: /from\s+['"]ws['"]/, why: 'ws import in sim' },
  { re: /from\s+['"]better-sqlite3['"]/, why: 'db import in sim' },
];

function walk(dir: string): string[] {
  let out: string[] = [];
  let entries: string[];
  try {
    entries = readdirSync(dir);
  } catch {
    return out; // dir may not exist yet (empty milestone) — that's fine
  }
  for (const e of entries) {
    const p = join(dir, e);
    if (statSync(p).isDirectory()) out = out.concat(walk(p));
    else if (['.ts', '.tsx'].includes(extname(p))) out.push(p);
  }
  return out;
}

const pkgRoot = fileURLToPath(new URL('..', import.meta.url));
let violations = 0;
for (const root of ROOTS) {
  for (const file of walk(join(pkgRoot, root))) {
    const lines = readFileSync(file, 'utf8').split('\n');
    lines.forEach((line, i) => {
      // skip line comments so prose like "no Date.now here" doesn't trip the lint
      const code = line.replace(/\/\/.*$/, '');
      for (const { re, why } of FORBIDDEN) {
        if (re.test(code)) {
          console.error(`PURITY VIOLATION ${file}:${i + 1}  ${why}\n    ${line.trim()}`);
          violations++;
        }
      }
    });
  }
}

if (violations > 0) {
  console.error(`\nlint:purity failed: ${violations} violation(s).`);
  process.exit(1);
}
console.log('lint:purity clean: sim core is I/O-free, clock-injected, seed-deterministic.');
