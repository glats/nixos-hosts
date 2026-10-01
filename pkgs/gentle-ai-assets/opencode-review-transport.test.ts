import { afterEach, describe, expect, mock, test } from "bun:test"
import { chmod, mkdtemp, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"

mock.module("@opencode/plugin", () => ({ Plugin: { define: (definition: unknown) => definition } }))
const { default: plugin, createReviewRelay } = await import("./v2-plugins/opencode-review-transport")

let directory: string
let oldPath: string | undefined
let oldMode: string | undefined

async function fakeCommand(mode = "normal") {
  directory = await mkdtemp(join(tmpdir(), "opencode-review-relay-"))
  const bin = join(directory, "gentle-ai")
  const log = join(directory, "calls")
  await writeFile(bin, `#!/usr/bin/env bun
import { appendFile, writeFile } from "node:fs/promises"
import { createInterface } from "node:readline"
await writeFile(${JSON.stringify(join(directory, "cwd"))}, process.cwd())
const input = createInterface({ input: process.stdin })
let first = true
for await (const line of input) {
  const value = JSON.parse(line)
  await appendFile(${JSON.stringify(log)}, JSON.stringify(value) + "\\n")
  if (first) {
    first = false
    if (${JSON.stringify(mode)} === "incomplete") process.exit(0)
    if (${JSON.stringify(mode)} === "go-fail") process.exit(1)
    if (${JSON.stringify(mode)} === "go-fail-bound") {
      console.error("Error: opencode_review_transport_binding_invalid: private path must not leak")
      process.exit(1)
    }
    process.stdout.write(JSON.stringify({ schema: "gentle-ai.provider-transport/v1", operation: "prompt", nonce: "test-nonce", prompt: "Go materialized review prompt" }) + "\\n")
  } else {
    if (value.error) process.exit(1)
    process.stdout.write(JSON.stringify({ schema: "gentle-ai.provider-transport/v1", operation: "result", output: "captured reviewer result" }) + "\\n")
  }
}
`)
  await chmod(bin, 0o755)
  oldPath = process.env.PATH
  process.env.PATH = `${directory}:${oldPath ?? ""}`
  oldMode = process.env.FAKE_RELAY_MODE
  return { bin, log }
}

afterEach(async () => {
  if (oldPath === undefined) delete process.env.PATH
  else process.env.PATH = oldPath
  if (oldMode === undefined) delete process.env.FAKE_RELAY_MODE
  else process.env.FAKE_RELAY_MODE = oldMode
  if (directory) await rm(directory, { recursive: true, force: true })
})

function harness(get = async () => ({ location: { directory } })) {
  const hooks = new Map<string, (input: any) => Promise<void> | void>()
  const ctx = {
    location: { directory: "/tmp" },
    session: { get },
    tool: { hook: async (name: string, callback: any) => { hooks.set(name, callback); return { dispose: async () => {} } } },
  }
  return { hooks, setup: () => (plugin as any).setup(ctx) }
}

describe("OpenCode V2 review relay", () => {
  test("relays the V1 start frame and returns the Go result", async () => {
    const { bin, log } = await fakeCommand()
    const relay = createReviewRelay(directory, "original review prompt", bin)
    expect(await relay.prompt).toEqual({ nonce: "test-nonce", prompt: "Go materialized review prompt" })
    expect(await relay.complete("completed Task output")).toBe("captured reviewer result")
    relay.close()
    const calls = (await Bun.file(log).text()).trim().split("\n").map(JSON.parse)
    expect(calls[0]).toEqual({ schema: "gentle-ai.provider-transport/v1", operation: "start", prompt: "original review prompt" })
    expect(calls[0].agent).toBeUndefined()
    expect(calls[1]).toEqual({ schema: "gentle-ai.provider-transport/v1", operation: "complete", nonce: "test-nonce", output: "completed Task output" })
  })

  test("relays only a requested review agent and preserves the completed result shape", async () => {
    await fakeCommand()
    const { hooks, setup } = harness()
    await setup()
    const event = { tool: "subagent", agent: "general", sessionID: "s", id: "1", input: { agent: "review-risk", prompt: "bound review" }, status: "completed", result: { output: { status: "completed", sessionID: "child", output: "raw reviewer result" }, content: "raw reviewer result" } }
    await hooks.get("execute.before")?.(event)
    expect(event.input.prompt).toBe("Go materialized review prompt")
    expect(await Bun.file(join(directory, "cwd")).text()).toBe(directory)
    await hooks.get("execute.after")?.(event)
    expect(event.result).toMatchObject({ output: { status: "completed", sessionID: "child", output: "captured reviewer result" }, content: "captured reviewer result" })
    const ordinary = { ...event, id: "2", input: { agent: "general", prompt: "ordinary" } }
    await hooks.get("execute.before")?.(ordinary)
    expect(ordinary.input.prompt).toBe("ordinary")
  })

  test("fails closed on incomplete relay output and cannot surface raw reviewer text", async () => {
    await fakeCommand("incomplete")
    const { hooks, setup } = harness()
    await setup()
    const event = { tool: "subagent", agent: "general", sessionID: "s", id: "1", input: { agent: "review-risk", prompt: "review" }, status: "completed", result: { output: { status: "completed", sessionID: "child", output: "raw reviewer output" }, content: "raw reviewer output" } }
    await expect(hooks.get("execute.before")?.(event)).rejects.toThrow()
    expect(event.input.prompt).toContain("opencode_review_transport_relay_refused")
    await expect(hooks.get("execute.after")?.(event)).rejects.toThrow()
    expect(event.result.content).toContain("opencode_review_transport_relay_refused")
    expect(event.result.content).not.toContain("raw reviewer output")
  })

  test("refuses when the Go executable is unavailable", async () => {
    const { bin } = await fakeCommand()
    await rm(bin)
    process.env.PATH = directory
    const missing = harness()
    await missing.setup()
    const event = { tool: "subagent", sessionID: "s", id: "missing", input: { agent: "review-risk", prompt: "bound review" } }
    await expect(missing.hooks.get("execute.before")?.(event)).rejects.toThrow("opencode_review_transport_relay_refused: executable_unavailable")
    expect(event.input.prompt).not.toContain("bound review")
  })

  test("distinguishes Go refusal without leaking its diagnostic output", async () => {
    await fakeCommand("go-fail")
    const rejected = harness()
    await rejected.setup()
    const goEvent = { tool: "subagent", sessionID: "s", id: "rejected", input: { agent: "review-risk", prompt: "bound review" } }
    await expect(rejected.hooks.get("execute.before")?.(goEvent)).rejects.toThrow("opencode_review_transport_relay_refused: go_refused")
  })

  test("reports only a known Go refusal code, never its diagnostic text", async () => {
    await fakeCommand("go-fail-bound")
    const { hooks, setup } = harness()
    await setup()
    const event = { tool: "subagent", sessionID: "s", id: "bound", input: { agent: "review-risk", prompt: "bound review" } }
    try {
      await hooks.get("execute.before")?.(event)
      throw new Error("review hook did not refuse")
    } catch (cause) {
      expect((cause as Error).message).toBe("opencode_review_transport_relay_refused: go_refused:binding_invalid")
    }
    expect(event.input.prompt).not.toContain("private path")
  })

  test("does not spawn if the session directory cannot be resolved", async () => {
    const { log } = await fakeCommand()
    const { hooks, setup } = harness(async () => { throw new Error("private session error") })
    await setup()
    const event = { tool: "subagent", sessionID: "s", id: "unavailable", input: { agent: "review-risk", prompt: "bound review" } }
    await expect(hooks.get("execute.before")?.(event)).rejects.toThrow("opencode_review_transport_relay_refused: relay_unavailable")
    expect(await Bun.file(log).exists()).toBe(false)
  })

  test("rejects incomplete child completion without admitting raw output", async () => {
    await fakeCommand()
    const { hooks, setup } = harness()
    await setup()
    const event = { tool: "subagent", agent: "general", sessionID: "s", id: "3", input: { agent: "review-risk", prompt: "review" }, status: "completed", result: { output: { status: "running", output: "raw reviewer output" }, content: "raw reviewer output" } }
    await hooks.get("execute.before")?.(event)
    await expect(hooks.get("execute.after")?.(event)).rejects.toThrow("opencode_review_transport_relay_refused")
    expect(event.result.content).not.toContain("raw reviewer output")
    expect(event.result.output.status).toBe("unavailable")
  })

  test("does not mutate the working directory", async () => {
    const { bin } = await fakeCommand()
    const marker = join(directory, "marker")
    await writeFile(marker, "unchanged")
    const relay = createReviewRelay(directory, "review", bin)
    await relay.prompt
    await relay.complete("result")
    relay.close()
    expect(await Bun.file(marker).text()).toBe("unchanged")
  })
})
