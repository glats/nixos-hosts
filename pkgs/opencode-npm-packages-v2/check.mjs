import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const output = resolve(process.argv[2]);
const modules = `${output}/lib/node_modules`;
const manifest = JSON.parse(readFileSync(new URL("./package.json", import.meta.url)));
const lock = JSON.parse(readFileSync(new URL("./package-lock.json", import.meta.url)));
assert.deepEqual(JSON.parse(readFileSync(`${output}/package.json`)), manifest.dependencies);
for (const [name, version] of Object.entries(manifest.dependencies)) {
  assert.equal(lock.packages[`node_modules/${name}`].version, version);
  assert.equal(JSON.parse(readFileSync(`${modules}/${name}/package.json`)).version, version);
}
for (const [path, entry] of Object.entries(lock.packages)) {
  if (path) assert.match(entry.integrity, /^sha512-/);
}
const { z } = await import(pathToFileURL(`${modules}/zod/index.js`));
assert.equal(z.string().parse("preserved"), "preserved");
const { Effect } = await import(pathToFileURL(`${modules}/effect/dist/index.js`));
assert.equal(Effect.runSync(Effect.succeed("preserved")), "preserved");
await import(pathToFileURL(`${modules}/@opencode/schema/dist/index.js`));
console.log("OpenCode: pins, integrities, layout, metadata, and representative imports passed");
