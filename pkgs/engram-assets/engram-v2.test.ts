import { afterEach, describe, expect, mock, test } from "bun:test"

mock.module("@opencode/plugin", () => ({ Plugin: { define: (definition: unknown) => definition } }))
const { default: plugin } = await import("./engram-v2")

type Hook = (input: any) => Promise<void> | void

const originalFetch = globalThis.fetch

afterEach(() => {
  globalThis.fetch = originalFetch
})

function harness() {
  const hooks = new Map<string, Hook>()
  const requests: Array<{ path: string; body?: any }> = []

  globalThis.fetch = (async (input, init) => {
    const url = new URL(String(input))
    const body = init?.body ? JSON.parse(String(init.body)) : undefined
    requests.push({ path: url.pathname + url.search, body })
    if (url.pathname === "/sessions/root") {
      return Response.json({ started_at: "2020-01-01 00:00:00" })
    }
    if (url.pathname === "/observations") return Response.json([{ created_at: "2020-01-01 00:00:00" }])
    if (url.pathname === "/context") return Response.json({ context: "prior context" })
    return Response.json({})
  }) as typeof fetch

  const ctx = {
    location: {
      directory: "/work/repo",
      project: { id: "project-id", directory: "/work/repo", canonical: "/work/repo" },
    },
    session: {
      hook(name: string, callback: Hook) {
        hooks.set(name, callback)
        return Promise.resolve({ dispose: async () => {} })
      },
      get: async ({ sessionID }: { sessionID: string }) =>
        ["root", "child"].includes(sessionID)
          ? { id: sessionID, parentID: sessionID === "child" ? "root" : undefined, projectID: "project-id" }
          : undefined,
    },
    tool: {
      hook(name: string, callback: Hook) {
        hooks.set(name, callback)
        return Promise.resolve({ dispose: async () => {} })
      },
    },
  }

  return { hooks, requests, setup: () => plugin.setup(ctx as any) }
}

describe("Engram V2 lifecycle adapter", () => {
  test("attributes child sessions to one registered root and injects all write tools", async () => {
    const { hooks, requests, setup } = harness()
    await setup()

    const tools = ["mem_save", "mem_save_prompt", "mem_session_summary", "mem_capture_passive"]
    for (const tool of tools) {
      const input = { tool, sessionID: "child", input: {} }
      await hooks.get("execute.before")?.(input)
      expect(input.input.session_id).toBe("root")
    }

    expect(requests.filter((request) => request.path === "/sessions")).toHaveLength(1)
  })

  test("does not capture child prompts under the root session", async () => {
    const { hooks, requests, setup } = harness()
    await setup()

    await hooks.get("prompt")?.({
      sessionID: "child",
      prompt: { text: "delegated child prompt that must not enter parent memory" },
      metadata: {},
    })

    expect(requests.some((request) => request.path === "/prompts")).toBe(false)
  })

  test("captures redacted prompts, Task output, memory context, nudge, and compaction directive", async () => {
    const { hooks, requests, setup } = harness()
    await setup()

    await hooks.get("prompt")?.({
      sessionID: "root",
      prompt: { text: "remember <private>secret</private> decision" },
      metadata: {},
    })
    await hooks.get("execute.after")?.({ tool: "Task", sessionID: "root" , input: {} , result: "A sufficiently long task result that should be passively captured." })

    const context = { sessionID: "root", system: [], messages: [], options: {}, tools: {} }
    await hooks.get("context")?.(context)
    const compaction = { sessionID: "root", system: [], messages: [], options: {}, tools: {} }
    await hooks.get("compaction")?.(compaction)

    expect(requests.find((request) => request.path === "/prompts")?.body.content).toContain("[REDACTED]")
    expect(requests.some((request) => request.path === "/observations/passive")).toBe(true)
    expect(context.system.map((part: any) => part.text).join("\n")).toContain("Engram")
    expect(context.system.map((part: any) => part.text).join("\n")).toContain("MEMORY REMINDER")
    expect(compaction.system.map((part: any) => part.text).join("\n")).toContain("FIRST ACTION REQUIRED")
  })

  test("fails closed for attributed writes and open for optional hooks", async () => {
    const { hooks, setup } = harness()
    await setup()

    const input = { tool: "mem_save", sessionID: "missing", input: {} }
    await expect(hooks.get("execute.before")?.(input)).rejects.toThrow()
    await expect(hooks.get("context")?.({ sessionID: "missing", system: [], messages: [] })).resolves.toBeUndefined()
  })
})
