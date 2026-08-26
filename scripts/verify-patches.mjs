// Verify the patch table in patches.json.
// Usage: node scripts/verify-patches.mjs [--target <node_modules root>]
// - Always: structural validation (unique anchors, old != new, marker present).
// - With --target: round-trip check against real installed bundle files
//   (revert -> clean -> reapply -> byte-identical), same as the author's CI.
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const here = new URL(".", import.meta.url);
const table = JSON.parse(readFileSync(new URL("../patches.json", here), "utf8"));
let failures = 0;
const fail = (msg) => { failures += 1; console.error("FAIL:", msg); };

for (const entry of table.files) {
  const seen = new Map();
  for (const p of entry.patches) {
    if (typeof p.old !== "string" || typeof p.new !== "string") fail(`${entry.package}: patch ${p.name} old/new must be strings`);
    if (p.old === p.new) fail(`${entry.package}: patch ${p.name} old == new (no-op)`);
    if (seen.has(p.old)) fail(`${entry.package}: duplicate anchor in patch ${p.name} and ${seen.get(p.old)}`);
    seen.set(p.old, p.name);
  }
  if (!entry.marker || entry.patches.length === 0) fail(`${entry.package}: missing marker or empty patch list`);
}

const targetArg = process.argv.find((a) => a.startsWith("--target="));
if (targetArg) {
  const root = targetArg.slice("--target=".length);
  for (const entry of table.files) {
    const bare = entry.package.replace(/^@[^/]+\//, "");
    const file = join(root, "@deepseek-ai", bare, entry.client);
    if (!existsSync(file)) { fail(`${entry.package}: target not found: ${file}`); continue; }
    const applyAll = (content, patches, forward) => {
      let c = content;
      const list = forward ? patches : [...patches].reverse();
      for (const p of list) {
        const [a, b] = forward ? [p.old, p.new] : [p.new, p.old];
        const i = c.indexOf(a);
        if (i < 0) throw new Error(`anchor missing: ${p.name}`);
        c = c.slice(0, i) + b + c.slice(i + a.length);
      }
      return c;
    };
    const actual = readFileSync(file, "utf8");
    try {
      const reverted = applyAll(actual, entry.patches, false);
      if (reverted.includes(entry.marker)) fail(`${entry.package}: revert still contains marker`);
      const reapplied = applyAll(reverted, entry.patches, true);
      if (reapplied !== actual) fail(`${entry.package}: reapply is not byte-identical`);
      else console.log(`OK  ${entry.package}: round-trip byte-identical`);
    } catch (e) {
      fail(`${entry.package}: ${e.message}`);
    }
  }
}

console.log(failures === 0 ? "ALL CHECKS PASSED" : `${failures} FAILURE(S)`);
process.exit(failures === 0 ? 0 : 1);
