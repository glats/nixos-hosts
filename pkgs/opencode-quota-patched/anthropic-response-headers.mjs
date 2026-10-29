function windowsFromHeaders(headers, now) {
  return [["5h", "5h"], ["7d", "Weekly"]].flatMap(([window, label]) => {
    const rawUsage = headers.get(`anthropic-ratelimit-unified-${window}-utilization`);
    const rawReset = headers.get(`anthropic-ratelimit-unified-${window}-reset`);
    if (!/^\d+(?:\.\d+)?$/.test(rawUsage ?? "") || !/^\d+(?:\.\d+)?$/.test(rawReset ?? "")) return [];
    const usage = Number(rawUsage);
    const reset = Number(rawReset) * 1000;
    if (!Number.isFinite(usage) || usage > 1 || !Number.isFinite(reset) || reset <= now || reset > 8640000000000000) return [];
    return [{ label, percentRemaining: Math.round((1 - usage) * 100), resetTimeIso: new Date(reset).toISOString(), observedAtIso: new Date(now).toISOString() }];
  });
}

function validSnapshot(value) {
  if (!value || typeof value.id !== "string" || !value.id || !Number.isFinite(value.checkedAt) || value.checkedAt < 0 || value.checkedAt > 8640000000000000) return false;
  if (!Array.isArray(value.windows) || value.windows.length === 0 || value.windows.length > 2) return false;
  return value.windows.every((window) =>
    window && ["5h", "Weekly"].includes(window.label) &&
    Number.isInteger(window.percentRemaining) && window.percentRemaining >= 0 && window.percentRemaining <= 100 &&
    typeof window.resetTimeIso === "string" && Number.isFinite(Date.parse(window.resetTimeIso)) &&
    typeof window.observedAtIso === "string" && Number.isFinite(Date.parse(window.observedAtIso))) &&
    new Set(value.windows.map((window) => window.label)).size === value.windows.length;
}

export function createAnthropicHeaderQuota(integration, now = Date.now, storage, storageKey = "anthropic-header-quota:v1") {
  const requests = new WeakMap();
  let generation = 0;
  let sequence = 0;
  let observed;
  let closed = false;
  let hydrated = false;
  let hydration;
  let pending = Promise.resolve();
  let persistence = storage ? "durable" : "memory";
  function write(operation) {
    pending = pending.then(operation).then(() => { persistence = storage ? "durable" : "memory"; }).catch(() => { persistence = "unavailable"; });
    return pending;
  }
  async function restore() {
    if (hydrated || !storage) return;
    hydration ??= (async () => {
      const epoch = generation;
      try {
        const value = await storage.get(storageKey);
        if (value !== undefined && !validSnapshot(value)) persistence = "invalid";
        if (validSnapshot(value) && !closed && epoch === generation && !observed) {
          observed = { id: value.id, checkedAt: value.checkedAt, windows: value.windows, epoch, order: 0 };
        }
      } catch {
        persistence = "unavailable";
      } finally {
        hydrated = true;
      }
    })();
    await hydration;
  }
  function invalidate() {
    generation += 1;
    observed = undefined;
    hydrated = true;
    return write(() => storage?.remove(storageKey));
  }
  async function activeKey() {
    try {
      const connection = await integration.connection.active("anthropic");
      return connection?.type === "credential" && connection.method === "key" ? connection.id : undefined;
    } catch {
      return undefined;
    }
  }
  return {
    invalidate,
    async credentialsChanged(event) {
      if (event.type === "credential.switched" && event.data?.integrationID === "anthropic") await invalidate();
    },
    async stop() {
      closed = true;
      generation += 1;
      observed = undefined;
      await pending;
    },
    async start(event) {
      const epoch = generation;
      const order = ++sequence;
      if (closed || event.model?.providerID !== "anthropic") return;
      const url = new URL(event.request.url);
      if (url.origin !== "https://api.anthropic.com" || url.pathname !== "/v1/messages") return;
      const id = await activeKey();
      if (id && !closed && epoch === generation) requests.set(event.request, { id, epoch, order });
    },
    async observe(event) {
      const request = requests.get(event.request);
      requests.delete(event.request);
      if (closed || !request || request.epoch !== generation) return;
      await restore();
      const checkedAt = now();
      const windows = windowsFromHeaders(event.response.headers, checkedAt);
      if (windows.length === 0) return;
      const id = await activeKey();
      if (closed || id !== request.id || request.epoch !== generation || (observed && observed.order > request.order)) return;
      const merged = new Map(observed?.id === id ? observed.windows.map((window) => [window.label, window]) : []);
      for (const window of windows) merged.set(window.label, window);
      observed = { ...request, checkedAt, windows: ["5h", "Weekly"].flatMap((label) => merged.has(label) ? [merged.get(label)] : []) };
      const snapshot = { id, checkedAt, windows: observed.windows };
      await write(() => storage?.set(storageKey, snapshot));
    },
    async read() {
      const epoch = generation;
      const id = await activeKey();
      if (closed || !id || epoch !== generation) return undefined;
      await restore();
      if (closed || epoch !== generation) return undefined;
      if (observed && observed.id !== id) await invalidate();
      const current = observed?.id === id && observed.epoch === generation ? observed : undefined;
      const entries = (current?.windows ?? []).map((window) => ({
        accounting: { resultType: "quota", acquisitionMethod: "remote_api", ownership: "maintained", authority: "provider_reported", sourceId: id, observedAtIso: window.observedAtIso },
        name: `Claude ${window.label}`,
        group: "Claude",
        label: `${window.label}:`,
        percentRemaining: window.percentRemaining,
        resetTimeIso: Date.parse(window.resetTimeIso) > now() ? window.resetTimeIso : undefined,
        right: `Last observed ${window.observedAtIso}`,
      }));
      return {
        entries,
        statusDetails: [
          { key: "quota_source", value: "response_headers" },
          { key: "persistence", value: persistence },
          { key: "message", value: entries.length ? "Last observed quota; retained across restarts until the Anthropic credential changes. Not a live balance." : "Awaiting quota headers from a normal Claude request." },
        ],
      };
    },
  };
}
