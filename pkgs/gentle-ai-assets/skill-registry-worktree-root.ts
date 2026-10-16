import type { Plugin } from "@opencode-ai/plugin"
import { execFile } from "child_process"
import { access } from "fs/promises"
import { homedir } from "os"
import { join, parse } from "path"
import { promisify } from "util"

const execFileAsync = promisify(execFile)

const PROJECT_MARKERS = [".git", ".atl", "skills", ".opencode/skills", ".claude/skills", ".gemini/skills", ".cursor/skills", ".github/skills", ".codex/skills", ".qwen/skills", ".kiro/skills", ".openclaw/skills", ".pi/skills", ".agent/skills", ".agents/skills", ".atl/skills", ".hermes/skills"]

async function pathExists(path: string): Promise<boolean> {
  try {
    await access(path)
    return true
  } catch {
    return false
  }
}

async function isProjectRoot(cwd: string): Promise<boolean> {
  if (!cwd) return false
  if (cwd === parse(cwd).root) return false
  if (cwd === homedir()) return false
  for (const marker of PROJECT_MARKERS) if (await pathExists(join(cwd, ...marker.split("/")))) return true
  return false
}

export const SkillRegistryPlugin: Plugin = async (input) => {
  async function refreshSkillRegistry() {
    const worktreeIsRoot = !input.worktree || input.worktree === parse(input.worktree).root
    const cwd = worktreeIsRoot ? (input.directory || process.cwd()) : input.worktree

    if (!(await isProjectRoot(cwd))) {
      console.error("[skill-registry] skipping refresh: not a project root:", cwd)
      return
    }

    try {
      await execFileAsync(
        "gentle-ai",
        ["skill-registry", "refresh", "--quiet", "--no-gitignore", "--cwd", cwd],
        { timeout: 30_000 },
      )
    } catch (err) {
      console.error("[skill-registry] refresh failed:", err)
    }
  }

  refreshSkillRegistry().catch((err) => {
    console.error("[skill-registry] unexpected refresh error:", err)
  })

  return {}
}

export default SkillRegistryPlugin
