import { afterEach, describe, expect, mock, test } from "bun:test"
import { execFileSync } from "node:child_process"
import { chmod, mkdtemp, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"

mock.module("@opencode/plugin", () => ({ Plugin: { define: (definition: unknown) => definition } }))
// Exercise the exact tagged implementation, not a copied local relay. Nix only
// adapts the command path; the HM wrapper is tested independently.
const source = execFileSync("nix", ["eval", "--offline", "--impure", "--raw", "--expr",
  '(builtins.getFlake (toString ./.)).inputs.gentle-ai-src.outPath'], { encoding: "utf8" }).trim()
const { default: plugin } = await import(`${source}/internal/assets/opencode/plugins-v2/opencode-review-transport.ts`)
let directory = ""
let oldPath: string | undefined
const cleanups: Array<() => Promise<void>> = []

async function fakeCommand(mode = "normal") {
  directory = await mkdtemp(join(tmpdir(), "opencode review 'relay'-"))
  const bin = join(directory, "gentle-ai")
  await writeFile(bin, `#!/usr/bin/env bun
import { appendFile, writeFile } from "node:fs/promises"
import { createInterface } from "node:readline"
await writeFile(${JSON.stringify(join(directory, "cwd"))}, process.cwd())
await writeFile(${JSON.stringify(join(directory, "relay-contract"))}, process.env.GENTLE_AI_OPENCODE_RELAY_CONTRACT ?? "")
let first = true
for await (const line of createInterface({ input: process.stdin })) {
  const frame = JSON.parse(line)
  await appendFile(${JSON.stringify(join(directory, "calls"))}, JSON.stringify(frame) + "\\n")
  if (first) {
    first = false
    if (${JSON.stringify(mode)} === "incomplete") process.exit(0)
    const badPrompt = {
      "empty-nonce": {schema:"gentle-ai.provider-transport/v1",operation:"prompt",nonce:"",prompt:"prompt"},
      "empty-prompt": {schema:"gentle-ai.provider-transport/v1",operation:"prompt",nonce:"nonce",prompt:""},
      "wrong-schema": {schema:"foreign/v1",operation:"prompt",nonce:"nonce",prompt:"prompt"},
    }[${JSON.stringify(mode)}]
    if (badPrompt) { process.stdout.write(JSON.stringify(badPrompt)+"\\n"); process.exit(0) }
    if (${JSON.stringify(mode)} === "malformed") { process.stdout.write("not-json\\n"); process.exit(0) }
    if (${JSON.stringify(mode)} === "truncated") { process.stdout.write('{"schema":'); process.exit(0) }
    if (${JSON.stringify(mode)} === "empty-result") {
      process.stdout.write(JSON.stringify({schema:"gentle-ai.provider-transport/v1",operation:"prompt",nonce:"test-nonce",prompt:"Go materialized review prompt"})+"\\n")
      continue
    }
    if (${JSON.stringify(mode)} !== "normal") {
      process.stdout.write(JSON.stringify({schema:"gentle-ai.provider-transport/v1",operation:"refused",error:${JSON.stringify(mode)}}) + "\\n")
      process.exit(1)
    }
    process.stdout.write(JSON.stringify({schema:"gentle-ai.provider-transport/v1",operation:"prompt",nonce:"test-nonce",prompt:"Go materialized review prompt"}) + "\\n")
  } else {
    if (frame.error) process.exit(1)
    process.stdout.write(JSON.stringify({schema:"gentle-ai.provider-transport/v1",operation:"result",output:${JSON.stringify(mode)} === "empty-result" ? "" : "captured reviewer result"}) + "\\n")
  }
}
`)
  await chmod(bin, 0o755)
  oldPath = process.env.PATH
  process.env.PATH = `${directory}:${oldPath ?? ""}`
  return bin
}

afterEach(async () => {
  for (const cleanup of cleanups.splice(0)) await cleanup()
  if (oldPath === undefined) delete process.env.PATH
  else process.env.PATH = oldPath
  if (directory) await rm(directory, { recursive: true, force: true })
})

async function harness() {
  const hooks = new Map<string, (input: any) => Promise<void> | void>()
  const register = async (name: string, callback: any) => {
    hooks.set(name, callback)
    return { dispose: async () => {} }
  }
  const ctx = {
    location: { directory, workspaceID: "fixture" },
    tool: { hook: register }, shell: { hook: register },
    event: { async *subscribe({ signal }: { signal: AbortSignal }) {
      await new Promise(resolve => signal.addEventListener("abort", resolve, { once: true }))
    } },
  }
  const cleanup = await (plugin as any).setup(ctx)
  hooks.set("fixture.dispose", cleanup)
  cleanups.push(cleanup)
  return hooks
}
function event(agent = "review-risk") {
  return { tool: "subagent", sessionID: "parent", id: "1", input: { agent, prompt: "Go-issued task" } as Record<string, unknown>, status: "completed",
    result: { output: { status: "completed", sessionID: "child", output: "opaque raw output" }, content: "opaque raw output" } }
}
async function calls() { return (await Bun.file(join(directory, "calls")).text()).trim().split("\n").map(JSON.parse) }

describe("Tagged OpenCode V2 review relay", () => {
  test("retains provider-transport/v1 wire and returns the Go result", async () => {
    await fakeCommand(); const hooks = await harness(); const call = event()
    await hooks.get("execute.before")!(call)
    expect(call.input.prompt).toBe("Go materialized review prompt")
    await hooks.get("execute.after")!(call)
    expect(call.result.content).toBe("captured reviewer result")
    expect((await calls())[1]).toEqual({schema:"gentle-ai.provider-transport/v1",operation:"complete",nonce:"test-nonce",output:"opaque raw output"})
  })
  test("relays only requested review agents and preserves terminal shape", async () => {
    await fakeCommand(); const hooks = await harness(); const call = event()
    await hooks.get("execute.before")!(call); await hooks.get("execute.after")!(call)
    expect(call.result.output).toMatchObject({status:"completed",sessionID:"child",output:"captured reviewer result"})
    const ordinary = event("general"); await hooks.get("execute.before")!(ordinary)
    expect(ordinary.input.prompt).toBe("Go-issued task")
  })
  test("fails closed on incomplete relay output without surfacing reviewer text", async () => {
    await fakeCommand("incomplete"); const hooks = await harness(); const call = event()
    await expect(hooks.get("execute.before")!(call)).rejects.toThrow("relay_unavailable")
    await expect(hooks.get("execute.after")!(call)).rejects.toThrow("relay_unavailable")
    expect(call.result.content).not.toContain("opaque raw output")
  })
  test("refuses when the Go executable is unavailable", async () => {
    const bin = await fakeCommand(); await rm(bin); process.env.PATH = directory
    const hooks = await harness(); await expect(hooks.get("execute.before")!(event())).rejects.toThrow("relay_unavailable")
  })
  test("forwards only Go's bounded typed refusal reason", async () => {
    await fakeCommand("agent_mismatch"); const hooks = await harness()
    await expect(hooks.get("execute.before")!(event())).rejects.toThrow("agent_mismatch")
  })
  test("unknown diagnostics cannot leak as a refusal reason", async () => {
    await fakeCommand("private path must not leak"); const hooks = await harness(); const call = event()
    await expect(hooks.get("execute.before")!(call)).rejects.toThrow("relay_unavailable")
    expect(call.input.prompt).not.toContain("private path")
  })
  test("background and reused child-session dispatch refuse before spawn", async () => {
    await fakeCommand(); const hooks = await harness()
    for (const input of [{background:true}, {sessionID:"old-child"}]) {
      const call = event(); Object.assign(call.input,input)
      await expect(hooks.get("execute.before")!(call)).rejects.toThrow("dispatch_refused")
    }
    expect(await Bun.file(join(directory,"calls")).exists()).toBe(false)
  })
  test("rejects running child acknowledgements without admitting raw output", async () => {
    await fakeCommand(); const hooks = await harness(); const call = event(); call.result.output.status = "running"
    await hooks.get("execute.before")!(call)
    await expect(hooks.get("execute.after")!(call)).rejects.toThrow("relay_unavailable")
    expect(call.result.content).not.toContain("opaque raw output")
  })
  test("uses bound runtime cwd without mutating working-tree bytes", async () => {
    await fakeCommand(); await writeFile(join(directory,"marker"),"unchanged")
    const hooks = await harness(); const call = event()
    await hooks.get("execute.before")!(call); await hooks.get("execute.after")!(call)
    expect(await Bun.file(join(directory,"cwd")).text()).toBe(directory)
    expect(await Bun.file(join(directory,"marker")).text()).toBe("unchanged")
  })
  test("forwards dispatched role and declares staged V2 contract to child and shell", async () => {
    await fakeCommand(); const hooks = await harness(); const call = event("review-refuter")
    await hooks.get("execute.before")!(call); await hooks.get("execute.after")!(call)
    expect((await calls())[0]).toEqual({schema:"gentle-ai.provider-transport/v1",operation:"start",prompt:"Go-issued task",agent:"review-refuter"})
    expect(await Bun.file(join(directory,"relay-contract")).text()).toBe("gentle-ai.opencode-relay/v2-staged")
    const shell = {env:{} as Record<string,string>}; await hooks.get("create.before")!(shell)
    expect(shell.env.GENTLE_AI_OPENCODE_RELAY_CONTRACT).toBe("gentle-ai.opencode-relay/v2-staged")
  })
  for (const mode of ["empty-nonce", "empty-prompt", "wrong-schema", "malformed", "truncated"]) {
    test(`refuses ${mode} start frames`, async () => {
      await fakeCommand(mode); const hooks = await harness(); const call = event()
      await expect(hooks.get("execute.before")!(call)).rejects.toThrow("relay_unavailable")
      await expect(hooks.get("execute.after")!(call)).rejects.toThrow("relay_unavailable")
      expect(call.result.content).not.toContain("opaque raw output")
    })
  }
  test("refuses an empty Go result", async () => {
    await fakeCommand("empty-result"); const hooks = await harness(); const call = event()
    await hooks.get("execute.before")!(call)
    await expect(hooks.get("execute.after")!(call)).rejects.toThrow("relay_unavailable")
    expect(call.result.content).not.toContain("opaque raw output")
  })
  for (const changed of ["agent", "sessionID", "id"]) {
    test(`completion cannot borrow a different ${changed} registration`, async () => {
      await fakeCommand(); const hooks = await harness(); const call = event()
      await hooks.get("execute.before")!(call)
      if (changed === "agent") call.input.agent = "review-validator"
      else call[changed] = "other"
      await expect(hooks.get("execute.after")!(call)).rejects.toThrow("relay_unavailable")
      expect((await calls()).length).toBe(1)
      expect(call.result.content).not.toContain("opaque raw output")
    })
  }
  test("duplicate before shares one relay; replayed completion refuses", async () => {
    await fakeCommand(); const hooks = await harness(); const call = event()
    await hooks.get("execute.before")!(call); await hooks.get("execute.before")!(call)
    await hooks.get("execute.after")!(call)
    expect((await calls()).length).toBe(2)
    await expect(hooks.get("execute.after")!(call)).rejects.toThrow("relay_unavailable")
  })
  test("duplicate instances defer to the owner and do not double-complete", async () => {
    await fakeCommand(); const owner = await harness(); const other = await harness(); const call = event()
    await owner.get("execute.before")!(call); await other.get("execute.before")!(call)
    await other.get("execute.after")!(call); await owner.get("execute.after")!(call)
    expect((await calls()).length).toBe(2)
    expect(call.result.content).toBe("captured reviewer result")
  })
  test("disposal invalidates owned pending completion and future dispatch", async () => {
    await fakeCommand(); const hooks = await harness(); const call = event()
    await hooks.get("execute.before")!(call); await hooks.get("fixture.dispose")!({})
    await expect(hooks.get("execute.after")!(call)).rejects.toThrow("relay_unavailable")
    await expect(hooks.get("execute.before")!(event())).rejects.toThrow("relay_unavailable")
    expect(call.result.content).not.toContain("opaque raw output")
  })
  test("unrelated instance disposal cannot kill another owner's relay", async () => {
    await fakeCommand(); const owner = await harness(); const other = await harness(); const call = event()
    await owner.get("execute.before")!(call); await other.get("fixture.dispose")!({})
    await owner.get("execute.after")!(call)
    expect(call.result.content).toBe("captured reviewer result")
  })
  test("opaque multiline/quoted raw bytes travel unchanged with Go's nonce", async () => {
    await fakeCommand(); const hooks = await harness(); const call = event()
    const raw = "  opaque 'quoted' \nresult\t\u0000—not a verdict  "
    call.result.output.output = raw
    await hooks.get("execute.before")!(call); await hooks.get("execute.after")!(call)
    expect((await calls())[1].output).toBe(raw)
    expect((await calls())[1].nonce).toBe("test-nonce")
  })
})
