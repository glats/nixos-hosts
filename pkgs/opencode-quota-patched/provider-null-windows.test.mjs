import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
import { join } from "node:path";

const root = process.argv[2];
const load = (path) => import(pathToFileURL(join(root, path)).href);
const { anthropicProvider } = await load("dist/providers/anthropic.js");
const { bindCredentialSource } = await load("dist/lib/opencode-auth.js");

let tokenCounter = 0;
bindCredentialSource({
  kind: "fixture",
  async readRows() {
    tokenCounter += 1;
    return [{
      id: "c1",
      integrationId: "anthropic",
      label: "default",
      active: true,
      method: "oauth",
      value: { type: "oauth", access: `fixture-token-${tokenCounter}`, refresh: "r", expires: Date.now() + 3600000 },
    }];
  },
});

async function entriesFor(body) {
  globalThis.fetch = async () => new Response(JSON.stringify(body), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
  return await anthropicProvider.fetch({ config: { requestTimeoutMs: 1000 }, client: {} });
}

const enterprise = await entriesFor({
  five_hour: null,
  seven_day: null,
  extra_usage: { is_enabled: true, utilization: 12.5, monthly_limit: 20000, used_credits: 2500, currency: "USD" },
});
assert.deepEqual(enterprise.entries.map((e) => e.label), ["Monthly:"]);
const monthly = enterprise.entries[0];
assert.equal(monthly.right, "$25.00/$200.00");
assert.equal(monthly.percentRemaining, 88);
const message = (enterprise.statusDetails ?? []).find((x) => x.key === "message")?.value ?? "";
assert.doesNotMatch(message, /Cannot read properties of null/);

const pro = await entriesFor({
  five_hour: { utilization: 10, resets_at: "2026-10-20T00:00:00Z" },
  seven_day: { utilization: 20, resets_at: "2026-10-20T00:00:00Z" },
  extra_usage: { is_enabled: true, utilization: 30, monthly_limit: 5000, used_credits: 1500, currency: "USD" },
});
assert.deepEqual(pro.entries.map((e) => e.label), ["5h:", "Weekly:", "Monthly:"]);
assert.equal(pro.entries[2].right, undefined, "Pro Monthly entry output must stay unchanged");
console.log("PASS: enterprise provider entries and diagnostics; Pro entries unchanged");
