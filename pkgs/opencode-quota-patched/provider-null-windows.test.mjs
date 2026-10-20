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

let rows = [];
bindCredentialSource({ kind: "fixture", async readRows() { return rows; } });
const login = (id, email, active, organization = "Acme") => ({
  id,
  integrationId: "anthropic",
  label: email,
  active,
  method: "oauth",
  value: {
    type: "oauth",
    access: `fixture-token-${id}-${Date.now()}`,
    refresh: "r",
    expires: Date.now() + 3600000,
    email,
    organization,
  },
});
let probedTokens = [];
async function probe() {
  probedTokens = [];
  globalThis.fetch = async (_url, init) => {
    probedTokens.push(init.headers.Authorization);
    return new Response(JSON.stringify({
      five_hour: null,
      seven_day: null,
      extra_usage: { is_enabled: true, utilization: 52, monthly_limit: 15000, used_credits: 7758, currency: "USD" },
    }), { status: 200, headers: { "content-type": "application/json" } });
  };
  return await anthropicProvider.fetch({ config: { requestTimeoutMs: 1000 }, client: {} });
}

rows = [login("new", "user@example.com", false), login("act", "User@Example.com", true), login("old", "user@example.com", false)];
const deduped = await probe();
assert.equal(probedTokens.length, 1, "one usage probe per account");
assert.match(probedTokens[0], /fixture-token-act-/, "the active login wins");
assert.equal(deduped.entries.length, 1);
assert.doesNotMatch(deduped.entries[0].group, / 2\b/);

rows = [login("a", "one@example.com", true), login("b", "two@example.com", false), login("c", "one@example.com", false, "Other")];
const distinct = await probe();
assert.equal(probedTokens.length, 3, "different accounts or organizations stay separate");
assert.equal(distinct.entries.length, 3);

rows = [login("n1", "user@example.com", false), login("n2", "user@example.com", false)];
await probe();
assert.equal(probedTokens.length, 1);
assert.match(probedTokens[0], /fixture-token-n1-/, "without an active login the newest one wins");
console.log("PASS: one probe per Anthropic account, active first, distinct accounts kept");
console.log("PASS: enterprise provider entries and diagnostics; Pro entries unchanged");
