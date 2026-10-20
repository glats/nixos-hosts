import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
import { join } from "node:path";

const root = process.argv[2];
const { queryAnthropicQuotaWithOAuth } = await import(
  pathToFileURL(join(root, "dist/lib/anthropic.js")).href
);

let nextBody;
let requests = 0;
globalThis.fetch = async (url) => {
  requests += 1;
  assert.equal(url, "https://api.anthropic.com/api/oauth/usage");
  return new Response(JSON.stringify(nextBody), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
};

async function query(body, token) {
  nextBody = body;
  return await queryAnthropicQuotaWithOAuth(token, 1000);
}

const window = (utilization) => ({ utilization, resets_at: "2026-10-20T00:00:00Z" });

const pro = await query(
  { five_hour: window(25), seven_day: window(40), extra_usage: { is_enabled: false } },
  "fixture-token-pro",
);
assert.deepEqual(pro, {
  success: true,
  five_hour: { percentRemaining: 75, resetTimeIso: "2026-10-20T00:00:00.000Z" },
  seven_day: { percentRemaining: 60, resetTimeIso: "2026-10-20T00:00:00.000Z" },
});

const proCredits = await query(
  {
    five_hour: window(10),
    seven_day: window(20),
    extra_usage: { is_enabled: true, utilization: 30, monthly_limit: 10000, used_credits: 3000, currency: "USD" },
  },
  "fixture-token-pro-credits",
);
assert.deepEqual(proCredits.extra_usage, { percentRemaining: 70, usedUsd: 30, limitUsd: 100, currency: "USD" });
assert.equal(proCredits.five_hour.percentRemaining, 90);

const enterprise = await query(
  {
    five_hour: null,
    seven_day: null,
    extra_usage: { is_enabled: true, utilization: 20, monthly_limit: 25000, used_credits: 5000, currency: "USD" },
  },
  "fixture-token-enterprise",
);
assert.deepEqual(enterprise, {
  success: true,
  five_hour: null,
  seven_day: null,
  extra_usage: { percentRemaining: 80, usedUsd: 50, limitUsd: 250, currency: "USD" },
});

const unknown = await query(
  { five_hour: null, seven_day: null, extra_usage: { is_enabled: false }, iguana_necktie: 1 },
  "fixture-token-unknown",
);
assert.equal(unknown.success, false);
assert.equal(
  unknown.error,
  "Unexpected Anthropic quota response shape (keys: extra_usage, five_hour, iguana_necktie, seven_day)",
);

assert.equal(requests, 4);

const { anthropicProvider } = await import(
  pathToFileURL(join(root, "dist/providers/anthropic.js")).href
);
assert.equal(anthropicProvider.id, "anthropic");
console.log("PASS: enterprise spend limit, null windows, Pro windows unchanged, shape keys reported");
