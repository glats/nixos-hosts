import { Plugin } from "@opencode/plugin"

const ENGRAM_PORT = Number.parseInt(process.env.ENGRAM_PORT ?? "7437", 10)
const ENGRAM_URL = `http://127.0.0.1:${ENGRAM_PORT}`
const ENGRAM_BIN = process.env.ENGRAM_BIN ?? "engram"
const WRITE_TOOLS = new Set(["mem_save", "mem_save_prompt", "mem_session_summary", "mem_capture_passive"])

const MEMORY_INSTRUCTIONS = `## Engram Persistent Memory — Protocol

You have access to Engram, a persistent memory system that survives across sessions and compactions.

Before the first project-scoped memory call, call mem_current_project to discover the current project. Use the exact returned project for mem_context, mem_search, mem_save, and mem_session_summary. Never infer the project from the directory basename or OpenCode project ID. On unknown_project, call mem_current_project again and use its returned project instead of retrying an invented name. Preserve intentional cross-project queries; discovery identifies the current project, not every query's target.

Call mem_save immediately after bug fixes, decisions, discoveries, configuration changes, established patterns, or learned preferences. Include What, Why, Where, and Learned in the content. Use project scope by default and a stable topic_key for evolving topics.

When asked to recall prior work, discover the project first. After project discovery, call mem_context first, then mem_search if needed. Use mem_session_summary before ending a session and after compaction. Save important observations immediately; this memory survives future sessions.`

function stripPrivateTags(value: string): string {
  return value.replace(/<private>[\s\S]*?<\/private>/gi, "[REDACTED]").trim()
}

function projectName(directory: string, projectID: string): string {
  try {
    const result = Bun.spawnSync(["git", "-C", directory, "remote", "get-url", "origin"])
    if (result.exitCode === 0) {
      const remote = new TextDecoder().decode(result.stdout).trim().replace(/\.git$/, "")
      const name = remote.split(/[/:]/).pop()
      if (name) return name
    }
  } catch {}
  return projectID || directory.split("/").pop() || "unknown"
}

async function request(path: string, options: RequestInit = {}): Promise<any> {
  try {
    const response = await fetch(`${ENGRAM_URL}${path}`, {
      ...options,
      headers: options.body ? { "Content-Type": "application/json", ...options.headers } : options.headers,
      signal: AbortSignal.timeout(3000),
    })
    if (!response.ok) return null
    return await response.json().catch(() => ({}))
  } catch {
    return null
  }
}

function addSystem(system: Array<{ type: "text"; text: string }>, text: string): void {
  const last = system.at(-1)
  if (last?.type === "text") last.text += `\n\n${text}`
  else system.push({ type: "text", text })
}

export default Plugin.define({
  id: "engram",
  async setup(ctx) {
    const directory = ctx.location.directory
    const project = projectName(directory, ctx.location.project.id)
    const parents = new Map<string, string | null>()
    const registered = new Set<string>()
    const invalid = new Set<string>()
    const nudged = new Map<string, number>()

    async function resolveRoot(sessionID: string): Promise<string> {
      if (!sessionID || invalid.has(sessionID)) return ""
      const visited = new Set<string>()
      let current = sessionID
      while (!visited.has(current)) {
        visited.add(current)
        let parent = parents.get(current)
        if (parent === undefined) {
          try {
            const info = await ctx.session.get({ sessionID: current }) as { id?: unknown; parentID?: unknown; projectID?: unknown }
            if (info?.id !== current || info.projectID !== ctx.location.project.id) return ""
            parent = info.parentID === undefined ? null : typeof info.parentID === "string" ? info.parentID : ""
            if (parent === "") return ""
            parents.set(current, parent)
          } catch {
            return ""
          }
        }
        if (parent === null) return current
        if (invalid.has(parent)) return ""
        current = parent
      }
      return ""
    }

    async function ensureSession(sessionID: string): Promise<boolean> {
      if (!sessionID || invalid.has(sessionID)) return false
      if (registered.has(sessionID)) return true
      const response = await request("/sessions", {
        method: "POST",
        body: JSON.stringify({ id: sessionID, project, directory }),
      })
      if (response === null) return false
      registered.add(sessionID)
      return true
    }

    if (!Bun.which(ENGRAM_BIN)) return
    const health = await request("/health")
    if (health === null) {
      try {
        Bun.spawn([ENGRAM_BIN, "serve"], { stdout: "ignore", stderr: "ignore", stdin: "ignore" })
      } catch {}
    }

    await ctx.session.hook("prompt", async (event) => {
      const root = await resolveRoot(event.sessionID)
      event.metadata = { ...event.metadata, engram_session_id: root || event.sessionID }
      const text = event.prompt.text.trim()
      if (!root || root !== event.sessionID || text.length <= 10 || !(await ensureSession(root))) return
      await request("/prompts", {
        method: "POST",
        body: JSON.stringify({ session_id: root, content: stripPrivateTags(text.slice(0, 2000)), project }),
      })
    })

    await ctx.tool.hook("execute.before", async (event) => {
      if (!WRITE_TOOLS.has(event.tool.toLowerCase())) return
      const root = await resolveRoot(event.sessionID)
      if (!root || !(await ensureSession(root))) {
        throw new Error(`Engram could not register session for ${event.tool}`)
      }
      if (!event.input || typeof event.input !== "object") {
        throw new Error(`Engram could not inject session for ${event.tool}`)
      }
      ;(event.input as Record<string, unknown>).session_id = root
    })

    await ctx.tool.hook("execute.after", async (event) => {
      if (event.status === "error" || event.tool !== "Task") return
      const root = await resolveRoot(event.sessionID)
      if (!root || !(await ensureSession(root))) return
      const result = "result" in event ? JSON.stringify(event.result) : ""
      if (result.length <= 50) return
      await request("/observations/passive", {
        method: "POST",
        body: JSON.stringify({ session_id: root, content: stripPrivateTags(result), project, source: "task-complete" }),
      })
    })

    async function addNudge(sessionID: string, system: Array<{ type: "text"; text: string }>): Promise<void> {
      const now = Math.floor(Date.now() / 1000)
      if (now - (nudged.get(sessionID) ?? 0) < 900) return
      const session = await request(`/sessions/${encodeURIComponent(sessionID)}`)
      const observations = await request(`/observations?project=${encodeURIComponent(project)}&limit=1&sort=created_at:desc`)
      if (!session || !observations?.[0]) return
      const started = Date.parse(String(session.started_at).replace(" ", "T") + "Z") / 1000
      const saved = Date.parse(String(observations[0].created_at).replace(" ", "T") + "Z") / 1000
      if ((started && now - started < 300) || !saved || now - saved < 900) return
      addSystem(system, "MEMORY REMINDER: It has been over 15 minutes since your last memory save. Call mem_save now if you made decisions, discoveries, or completed significant work.")
      nudged.set(sessionID, now)
    }

    await ctx.session.hook("context", async (event) => {
      addSystem(event.system, `${MEMORY_INSTRUCTIONS}\n\nCurrent Engram project: ${JSON.stringify(project)}. Use this exact project name for current-project memory calls, not the directory name. If mem_current_project reports a different name, use its returned project.`)
      await addNudge(event.sessionID, event.system)
    })

    await ctx.session.hook("compaction", async (event) => {
      const root = await resolveRoot(event.sessionID)
      if (root) await ensureSession(root)
      const data = await request(`/context?project=${encodeURIComponent(project)}`)
      if (data?.context) addSystem(event.system, String(data.context))
      addSystem(event.system, `CRITICAL INSTRUCTION FOR COMPACTED SUMMARY:\nThe agent has access to Engram persistent memory via MCP tools.\n\nFIRST ACTION REQUIRED: Call mem_session_summary with the content of this compacted summary. Use project: '${project}'. Do this BEFORE any other work.`)
    })
  },
})
