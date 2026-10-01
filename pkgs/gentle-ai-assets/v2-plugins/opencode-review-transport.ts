import { spawn } from "node:child_process"
import { Plugin } from "@opencode/plugin"

const REVIEW_AGENTS = new Set([
  "review-risk",
  "review-resilience",
  "review-readability",
  "review-reliability",
  "review-refuter",
  "review-validator",
])
const SCHEMA = "gentle-ai.provider-transport/v1"
const REFUSED = "opencode_review_transport_relay_refused"
// The Nix asset replaces these invocation paths without changing Go-owned review semantics.
const GO_COMMAND = "gentle-ai"
const GIT_BIN = ""

type HookInput = {
  tool?: unknown
  sessionID?: unknown
  id?: unknown
  input?: unknown
  status?: unknown
  result?: unknown
  error?: unknown
}

type Frame = {
  schema: string
  operation: string
  nonce?: string
  prompt?: string
  output?: string
  error?: string
}

type Relay = {
  prompt: Promise<{ nonce: string; prompt: string }>
  complete(output: unknown): Promise<string>
  close(): void
}

function frame(line: string): Frame {
  const value: unknown = JSON.parse(line)
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("invalid Go transport response")
  const result = value as Frame
  if (result.schema !== SCHEMA) throw new Error("invalid Go transport schema")
  return result
}

// The command is injectable only for the fake-child tests; production uses the
// pinned gentle-ai CLI and keeps all binding, admission, and capture in Go.
export function createReviewRelay(cwd: string, prompt: string, command = GO_COMMAND): Relay {
  const child = spawn(command, ["review", "opencode-transport"], {
    cwd,
    stdio: ["pipe", "pipe", "pipe"],
    env: GIT_BIN ? { ...process.env, PATH: `${GIT_BIN}:${process.env.PATH ?? ""}` } : process.env,
  })
  let buffered = ""
  let closed = false
  let prompted = false
  let resolvePrompt!: (value: { nonce: string; prompt: string }) => void
  let rejectPrompt!: (reason: unknown) => void
  let resolveResult!: (value: string) => void
  let rejectResult!: (reason: unknown) => void
  const promptFrame = new Promise<{ nonce: string; prompt: string }>((resolve, reject) => {
    resolvePrompt = resolve
    rejectPrompt = reject
  })
  const resultFrame = new Promise<string>((resolve, reject) => {
    resolveResult = resolve
    rejectResult = reject
  })
  void promptFrame.catch(() => {})
  void resultFrame.catch(() => {})

  const fail = (cause: unknown) => {
    if (closed) return
    closed = true
    rejectPrompt(cause)
    rejectResult(cause)
  }

  child.stdout.on("data", (chunk: Buffer) => {
    buffered += chunk.toString("utf8")
    for (;;) {
      const newline = buffered.indexOf("\n")
      if (newline < 0) return
      const line = buffered.slice(0, newline)
      buffered = buffered.slice(newline + 1)
      try {
        const response = frame(line)
        if (response.operation === "prompt" && !prompted && typeof response.nonce === "string" && response.nonce !== "" && typeof response.prompt === "string" && response.prompt !== "") {
          prompted = true
          resolvePrompt({ nonce: response.nonce, prompt: response.prompt })
        } else if (response.operation === "result" && prompted && typeof response.output === "string" && response.output) {
          closed = true
          resolveResult(response.output)
        } else {
          throw new Error("invalid Go relay frame")
        }
      } catch (cause) {
        fail(cause)
      }
    }
  })
  child.stdin.on("error", fail)
  child.on("error", fail)
  child.on("close", (code) => {
    if (!closed) fail(new Error(`Go review relay exited before completion (${code ?? "signal"})`))
  })
  child.stdin.write(JSON.stringify({ schema: SCHEMA, operation: "start", prompt }) + "\n", (cause) => {
    if (cause) fail(cause)
  })

  return {
    prompt: promptFrame,
    complete: async (output) => {
      const materialized = await promptFrame
      const completion: Frame = { schema: SCHEMA, operation: "complete", nonce: materialized.nonce }
      if (typeof output === "string" && output.length > 0) completion.output = output
      else completion.error = "opencode_task_host_output_unavailable"
      child.stdin.end(JSON.stringify(completion) + "\n")
      return resultFrame
    },
    close: () => {
      if (!closed) fail(new Error("review relay closed"))
      if (!child.killed) child.kill()
    },
  }
}

function refusal(cause?: unknown): string {
  const reason = cause instanceof Error && cause.message.startsWith("Go review relay exited before completion")
    ? "go_refused"
    : cause && typeof cause === "object" && "code" in cause && cause.code === "ENOENT"
      ? "executable_unavailable"
      : "relay_unavailable"
  return `${REFUSED}: ${reason}`
}

function isReview(input: HookInput): boolean {
  if (input.tool !== "subagent" || !input.input || typeof input.input !== "object") return false
  const agent = (input.input as Record<string, unknown>).agent
  return typeof agent === "string" && REVIEW_AGENTS.has(agent)
}

function key(input: HookInput): string {
  return JSON.stringify([input.sessionID, input.id, (input.input as Record<string, unknown>).agent])
}

function resultOutput(input: HookInput): unknown {
  if (!input.result || typeof input.result !== "object") return undefined
  const child = (input.result as Record<string, unknown>).output
  if (!child || typeof child !== "object") return undefined
  const output = child as Record<string, unknown>
  return output.status === "completed" && typeof output.sessionID === "string" && output.sessionID !== "" && typeof output.output === "string" ? output.output : undefined
}

export default Plugin.define({
  id: "opencode-review-transport",
  async setup(ctx) {
    const relays = new Map<string, Relay>()
    const refused = new Map<string, string>()
    const before = await ctx.tool.hook("execute.before", async (raw) => {
      const input = raw as HookInput
      if (!isReview(input)) return
      const taskPrompt = typeof input.input === "object" && input.input !== null
        ? (input.input as Record<string, unknown>).prompt
        : undefined
      const relayKey = key(input)
      const args = input.input as Record<string, unknown>
      const deny = (cause?: unknown) => {
        const message = refusal(cause)
        refused.set(relayKey, message)
        args.prompt = message
        throw new Error(message)
      }
      if (relays.has(relayKey)) return deny()
      if (typeof taskPrompt !== "string" || taskPrompt.length === 0 || args.background === true || args.sessionID !== undefined) return deny()
      if (typeof input.sessionID !== "string" || input.sessionID === "") return deny()
      let cwd: string
      try {
        cwd = (await ctx.session.get({ sessionID: input.sessionID })).location.directory
      } catch { return deny() }
      if (typeof cwd !== "string" || cwd === "") return deny()
      let relay: Relay
      try { relay = createReviewRelay(cwd, taskPrompt) } catch (cause) { return deny(cause) }
      relays.set(relayKey, relay)
      try {
        args.prompt = (await relay.prompt).prompt
      } catch (cause) {
        relay.close()
        relays.delete(relayKey)
        return deny(cause)
      }
    })
    const after = await ctx.tool.hook("execute.after", async (raw) => {
      const input = raw as HookInput
      if (!isReview(input)) return
      const relayKey = key(input)
      const refusedOutput = refused.get(relayKey)
      if (refusedOutput) {
        refused.delete(relayKey)
        if (input.status === "completed") (input as { result?: Record<string, unknown> }).result = { output: { status: "unavailable", output: refusedOutput }, content: refusedOutput }
        throw new Error(refusedOutput)
      }
      const relay = relays.get(relayKey)
      if (!relay) {
        const message = refusal()
        if (input.status === "completed") (input as { result?: Record<string, unknown> }).result = { output: { status: "unavailable", output: message }, content: message }
        throw new Error(message)
      }
      try {
        const output = await relay.complete(resultOutput(input))
        if (input.status !== "completed") throw new Error("review subagent did not complete")
        const previous = input.result as Record<string, unknown>
        ;(input as { result?: Record<string, unknown> }).result = {
          ...previous,
          output: { ...(previous.output as Record<string, unknown>), output },
          content: output,
        }
      } catch (cause) {
        const message = refusal()
        if (input.status === "completed") (input as { result?: Record<string, unknown> }).result = { output: { status: "unavailable", output: message }, content: message }
        throw new Error(message)
      } finally {
        relays.delete(relayKey)
        relay.close()
      }
    })
    return async () => {
      await Promise.all([before.dispose(), after.dispose()])
      for (const relay of relays.values()) relay.close()
      relays.clear()
      refused.clear()
    }
  },
})
