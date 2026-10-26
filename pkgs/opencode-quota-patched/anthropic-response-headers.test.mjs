import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
import { join } from "node:path";

const root = process.argv[2];
const { createAnthropicHeaderQuota } = await import(pathToFileURL(join(root, "dist/lib/anthropic-response-headers.mjs")));
let time = 1800000000000;
let connection = { type: "credential", id: "first", method: "key" };
const integration = { connection: { active: async () => connection } };
const quota = createAnthropicHeaderQuota(integration, () => time);
const event = (headers = {}) => ({
  model: { providerID: "anthropic" },
  request: new Request("https://api.anthropic.com/v1/messages", { method: "POST" }),
  response: new Response("unchanged", { headers }),
});
const headers = {
  "anthropic-ratelimit-unified-5h-utilization": "0.11",
  "anthropic-ratelimit-unified-5h-reset": String(time / 1000 + 3600),
  "anthropic-ratelimit-unified-7d-utilization": "0.6",
  "anthropic-ratelimit-unified-7d-reset": String(time / 1000 + 86400),
};
globalThis.fetch = () => { throw new Error("passive quota must not fetch"); };
assert.deepEqual((await quota.read()).entries, []);
const first = event(headers);
await quota.start(first);
await quota.observe(first);
assert.equal(first.response.bodyUsed, false);
assert.equal(await first.response.text(), "unchanged");
assert.deepEqual((await quota.read()).entries.map(({ label, percentRemaining }) => [label, percentRemaining]), [["5h:", 89], ["Weekly:", 40]]);
assert.equal((await quota.read()).statusDetails.find(({ key }) => key === "quota_source").value, "response_headers");

const older = event(headers);
const newer = event({ ...headers, "anthropic-ratelimit-unified-5h-utilization": "0.2" });
await quota.start(older);
await quota.start(newer);
await quota.observe(newer);
await quota.observe(older);
assert.equal((await quota.read()).entries[0].percentRemaining, 80);

const missing = event({ "anthropic-ratelimit-tokens-remaining": "2000" });
await quota.start(missing);
await quota.observe(missing);
assert.equal((await quota.read()).entries[0].percentRemaining, 80);
time += 300001;
assert.deepEqual((await quota.read()).entries, []);
for (const invalid of ["", "NaN", "Infinity", "-0.1", "1.1", "0x1"]) {
  const bad = event({ ...headers, "anthropic-ratelimit-unified-5h-utilization": invalid, "anthropic-ratelimit-unified-7d-reset": "invalid" });
  await quota.start(bad);
  await quota.observe(bad);
  assert.deepEqual((await quota.read()).entries, [], invalid);
}

const partial = event({ "anthropic-ratelimit-unified-5h-utilization": "1", "anthropic-ratelimit-unified-5h-reset": String(time / 1000 + 1) });
await quota.start(partial);
await quota.observe(partial);
assert.deepEqual((await quota.read()).entries.map((entry) => entry.percentRemaining), [0]);
time += 1001;
assert.deepEqual((await quota.read()).entries, []);

const inflight = event(headers);
await quota.start(inflight);
quota.invalidate();
await quota.observe(inflight);
assert.deepEqual((await quota.read()).entries, []);
const switched = event(headers);
await quota.start(switched);
connection = { ...connection, id: "second" };
await quota.observe(switched);
assert.deepEqual((await quota.read()).entries, []);
connection = { ...connection, method: "oauth" };
assert.equal(await quota.read(), undefined, "OAuth must use its unchanged provider path");
connection = { ...connection, method: "key" };
const { anthropicProvider } = await import(pathToFileURL(join(root, "dist/providers/anthropic.js")));
const { bindCredentialSource } = await import(pathToFileURL(join(root, "dist/lib/opencode-auth.js")));
bindCredentialSource({ kind: "fixture", async readRows() { throw new Error("key header path must not read credentials"); } });
const ctx = { config: {}, client: { anthropicHeaderQuota: quota } };
const waiting = await anthropicProvider.fetch(ctx);
assert.deepEqual(waiting.entries, []);
const observed = event(headers);
await quota.start(observed);
await quota.observe(observed);
const result = await anthropicProvider.fetch(ctx);
assert.deepEqual(result.entries.map((entry) => entry.percentRemaining), [89, 40]);
assert.deepEqual(result.errors, []);
for (const [url, provider] of [["https://example.com/v1/messages", "anthropic"], ["https://api.anthropic.com/v1/messages", "other"]]) {
  quota.invalidate();
  const rejected = event(headers);
  rejected.request = new Request(url);
  rejected.model.providerID = provider;
  const before = JSON.stringify(connection);
  await quota.start(rejected);
  await quota.observe(rejected);
  assert.deepEqual((await quota.read()).entries, []);
  assert.equal(JSON.stringify(connection), before);
  assert.equal(rejected.response.bodyUsed, false);
}
const cloned = event(headers);
await quota.start(cloned);
await quota.observe({ ...cloned, request: cloned.request.clone() });
assert.deepEqual((await quota.read()).entries, []);
console.log("PASS: passive header windows, no fetch/body reads, expiry, ordering and credential isolation");
