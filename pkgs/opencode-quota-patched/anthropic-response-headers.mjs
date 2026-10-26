const MAX_AGE_MS = 5 * 60 * 1000;

function windowsFromHeaders(headers, now) {
  return [["5h", "5h"], ["7d", "Weekly"]].flatMap(([window, label]) => {
    const rawUsage = headers.get(`anthropic-ratelimit-unified-${window}-utilization`);
    const rawReset = headers.get(`anthropic-ratelimit-unified-${window}-reset`);
    if (!/^\d+(?:\.\d+)?$/.test(rawUsage ?? "") || !/^\d+(?:\.\d+)?$/.test(rawReset ?? "")) return [];
    const usage = Number(rawUsage);
    const reset = Number(rawReset) * 1000;
    if (!Number.isFinite(usage) || usage > 1 || !Number.isFinite(reset) || reset <= now || reset > 8640000000000000) return [];
    return [{ label, percentRemaining: Math.round((1 - usage) * 100), resetTimeIso: new Date(reset).toISOString() }];
  });
}

export function createAnthropicHeaderQuota(integration, now = Date.now) {
  const requests = new WeakMap();
  let generation = 0;
  let sequence = 0;
  let observed;
  async function activeKey() {
    try {
      const connection = await integration.connection.active("anthropic");
      return connection?.type === "credential" && connection.method === "key" ? connection.id : undefined;
    } catch {
      return undefined;
    }
  }
  return {
    invalidate() {
      generation += 1;
      observed = undefined;
    },
    async start(event) {
      const epoch = generation;
      const order = ++sequence;
      if (event.model?.providerID !== "anthropic") return;
      const url = new URL(event.request.url);
      if (url.origin !== "https://api.anthropic.com" || url.pathname !== "/v1/messages") return;
      const id = await activeKey();
      if (id && epoch === generation) requests.set(event.request, { id, epoch, order });
    },
    async observe(event) {
      const request = requests.get(event.request);
      requests.delete(event.request);
      if (!request || request.epoch !== generation) return;
      const checkedAt = now();
      const windows = windowsFromHeaders(event.response.headers, checkedAt);
      if (windows.length === 0) return;
      const id = await activeKey();
      if (id !== request.id || request.epoch !== generation || (observed && observed.order > request.order)) return;
      observed = { ...request, checkedAt, windows };
    },
    async read() {
      const epoch = generation;
      const id = await activeKey();
      if (!id || epoch !== generation) return undefined;
      const checkedAt = now();
      const current = observed?.id === id && observed.epoch === epoch && checkedAt >= observed.checkedAt && checkedAt - observed.checkedAt <= MAX_AGE_MS ? observed : undefined;
      const entries = (current?.windows ?? []).filter((window) => Date.parse(window.resetTimeIso) > checkedAt).map((window) => ({
        accounting: { resultType: "quota", acquisitionMethod: "remote_api", ownership: "maintained", authority: "provider_reported", sourceId: id },
        name: `Claude ${window.label}`,
        group: "Claude",
        label: `${window.label}:`,
        percentRemaining: window.percentRemaining,
        resetTimeIso: window.resetTimeIso,
      }));
      return {
        entries,
        statusDetails: [
          { key: "quota_source", value: "response_headers" },
          { key: "message", value: entries.length ? "Quota observed on a normal Claude response; expires after five minutes or window reset." : "Awaiting quota headers from a normal Claude request." },
        ],
      };
    },
  };
}
