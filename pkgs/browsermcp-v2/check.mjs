import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

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
for (const file of ["index.js", "daemon.js"]) {
  assert.ok(existsSync(`${modules}/@browsermcp/mcp/dist/${file}`), `missing dist/${file}`);
}

const home = mkdtempSync(join(tmpdir(), "browsermcp-check-"));
const child = spawn(`${output}/bin/mcp-server-browsermcp`, [], {
  env: { ...process.env, BROWSER_MCP_HOME: home },
  stdio: ["pipe", "pipe", "inherit"],
});
const reply = new Promise((resolveReply, reject) => {
  const timer = setTimeout(() => reject(new Error("no initialize reply")), 15000);
  let buffer = "";
  child.stdout.on("data", (chunk) => {
    buffer += chunk;
    const line = buffer.split("\n").find((l) => l.trim());
    if (line && buffer.includes("\n")) {
      clearTimeout(timer);
      resolveReply(JSON.parse(line));
    }
  });
  child.on("error", reject);
});
child.stdin.write(
  JSON.stringify({
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: {
      protocolVersion: "2025-03-26",
      capabilities: {},
      clientInfo: { name: "install-check", version: "1.0.0" },
    },
  }) + "\n",
);
try {
  const { result } = await reply;
  assert.ok(result.capabilities.tools, "must advertise tools");
  assert.equal(result.capabilities.resources, undefined, "must not advertise resources");
  assert.equal(result.serverInfo.name, "Browser MCP");
} finally {
  child.stdin.end();
  child.kill();
  rmSync(home, { recursive: true, force: true });
}
console.log("BrowserMCP: pin, integrities, layout, and MCP handshake (tools only) passed");
