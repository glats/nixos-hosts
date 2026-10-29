import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { execFileSync } from "node:child_process";

const output = resolve(process.argv[2]);
const modules = `${output}/lib/node_modules`;
const manifest = JSON.parse(readFileSync(new URL("./package.json", import.meta.url)));
const lock = JSON.parse(readFileSync(new URL("./package-lock.json", import.meta.url)));
for (const [name, version] of Object.entries(manifest.dependencies)) {
  assert.equal(lock.packages[`node_modules/${name}`].version, version);
  assert.equal(JSON.parse(readFileSync(`${modules}/${name}/package.json`)).version, version);
}
for (const [path, entry] of Object.entries(lock.packages)) {
  if (path) assert.match(entry.integrity, /^sha512-/);
}
const browser = readFileSync(`${modules}/@browsermcp/mcp/dist/index.js`, "utf8");
assert.ok(!browser.includes("  killProcessOnPort(port);\n"), "must not kill the port owner");
assert.ok(!browser.includes("        tools: {},\n        resources: {}"), "must not advertise resources");
const sdk = readFileSync(`${modules}/@modelcontextprotocol/sdk/dist/esm/server/index.js`, "utf8");
assert.ok(!sdk.includes("if (!this._capabilities.resources)"), "must accept retained resource handler");
const { Server } = await import(pathToFileURL(`${modules}/@modelcontextprotocol/sdk/dist/esm/server/index.js`));
const { ListResourcesRequestSchema } = await import(pathToFileURL(`${modules}/@modelcontextprotocol/sdk/dist/esm/types.js`));
const server = new Server({ name: "compatibility-test", version: "1.0.0" }, { capabilities: { tools: {} } });
server.setRequestHandler(ListResourcesRequestSchema, async () => ({ resources: [] }));
assert.match(execFileSync(`${output}/bin/mcp-server-browsermcp`, ["--help"], { encoding: "utf8" }), /Usage:/);
console.log("BrowserMCP: pins, integrities, layout, SDK compatibility, port protection, and CLI passed");
