#!/usr/bin/env python3
# verify-opencode.py — Test every model in every OpenCode tier list through opencode run.
#
# Unlike verify-tiers.py which tests the raw API, this script tests the full
# opencode↔provider↔model pipeline using `opencode run -m provider/model "prompt"`.
#
# This catches issues that raw API tests miss, such as:
# - Vercel AI SDK stripping unknown fields (e.g. chat_template_kwargs for DeepSeek V4)
# - reasoning_content not round-tripped in multi-turn conversations
# - Model name mapping issues between opencode config and actual API calls
# - Streaming/parsing bugs in the opencode provider layer
#
# Usage:
#   verify-opencode                  # Test all tiers
#   verify-opencode --tier nvidia    # Test one tier
#   verify-opencode --json           # JSON output
#   verify-opencode --timeout 60     # Custom timeout per model (default: 45s)
#   verify-opencode --prompt "Say OK"# Custom prompt (default: minimal)

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone

# ============================================================
# Tier lists — same as verify-tiers.py
# ============================================================

TIER_LISTS = {
    "nvidia": {
        "sdd-orchestrator": "nvidia/z-ai/glm-5.1",
        "sdd-init": "nvidia/openai/gpt-oss-20b",
        "sdd-explore": "nvidia/qwen/qwen3-coder-480b-a35b-instruct",
        "sdd-propose": "nvidia/z-ai/glm-5.1",
        "sdd-spec": "nvidia/nvidia/nemotron-3-super-120b-a12b",
        "sdd-design": "nvidia/z-ai/glm-5.1",
        "sdd-tasks": "nvidia/nvidia/nemotron-3-super-120b-a12b",
        "sdd-apply": "nvidia/minimaxai/minimax-m2.7",
        "sdd-verify": "nvidia/z-ai/glm-5.1",
        "sdd-archive": "nvidia/openai/gpt-oss-20b",
        "sdd-onboard": "nvidia/openai/gpt-oss-20b",
        "neutral": "nvidia/z-ai/glm-5.1",
    },
    "nvidia2": {
        "sdd-orchestrator": "nvidia/z-ai/glm5",
        "sdd-init": "nvidia/nvidia/nemotron-3-super-120b-a12b",
        "sdd-explore": "nvidia/qwen/qwen3-coder-480b-a35b-instruct",
        "sdd-propose": "nvidia/z-ai/glm5",
        "sdd-spec": "nvidia/qwen/qwen3-coder-480b-a35b-instruct",
        "sdd-design": "nvidia/z-ai/glm5",
        "sdd-tasks": "nvidia/qwen/qwen3-coder-480b-a35b-instruct",
        "sdd-apply": "nvidia/minimaxai/minimax-m2.7",
        "sdd-verify": "nvidia/z-ai/glm4.7",
        "sdd-archive": "nvidia/openai/gpt-oss-20b",
        "sdd-onboard": "nvidia/openai/gpt-oss-20b",
        "neutral": "nvidia/z-ai/glm5",
    },
    "nvidia3": {
        "sdd-orchestrator": "nvidia/z-ai/glm-5.1",
        "sdd-init": "nvidia/openai/gpt-oss-20b",
        "sdd-explore": "nvidia/qwen/qwen3-coder-480b-a35b-instruct",
        "sdd-propose": "nvidia/z-ai/glm-5.1",
        "sdd-spec": "nvidia/z-ai/glm-5.1",
        "sdd-design": "nvidia/z-ai/glm-5.1",
        "sdd-tasks": "nvidia/qwen/qwen3-coder-480b-a35b-instruct",
        "sdd-apply": "nvidia/minimaxai/minimax-m2.7",
        "sdd-verify": "nvidia/z-ai/glm-5.1",
        "sdd-archive": "nvidia/openai/gpt-oss-20b",
        "sdd-onboard": "nvidia/openai/gpt-oss-20b",
        "neutral": "nvidia/z-ai/glm-5.1",
    },
    "balanced": {
        "sdd-orchestrator": "nvidia/z-ai/glm-5.1",
        "sdd-init": "groq/llama-3.1-8b-instant",
        "sdd-explore": "cloudflare/@cf/meta/llama-4-scout-17b-16e-instruct",
        "sdd-propose": "mistral/magistral-medium-latest",
        "sdd-spec": "nvidia/qwen/qwen3-coder-480b-a35b-instruct",
        "sdd-design": "mistral/magistral-medium-latest",
        "sdd-tasks": "cohere/command-r-plus-08-2024",
        "sdd-apply": "mistral/devstral-medium-latest",
        "sdd-verify": "nvidia/z-ai/glm4.7",
        "sdd-archive": "cloudflare/@cf/openai/gpt-oss-20b",
        "sdd-onboard": "groq/llama-3.1-8b-instant",
        "neutral": "nvidia/z-ai/glm-5.1",
    },
    "quality": {
        "sdd-orchestrator": "nvidia/z-ai/glm-5.1",
        "sdd-init": "cohere/command-r7b-12-2024",
        "sdd-explore": "huggingface/deepseek-ai/DeepSeek-V3-0324",
        "sdd-propose": "mistral/magistral-medium-latest",
        "sdd-spec": "mistral/mistral-large-latest",
        "sdd-design": "cohere/command-a-reasoning-08-2025",
        "sdd-tasks": "nvidia/qwen/qwen3-coder-480b-a35b-instruct",
        "sdd-apply": "nvidia/minimaxai/minimax-m2.7",
        "sdd-verify": "mistral/magistral-medium-latest",
        "sdd-archive": "cohere/command-r7b-12-2024",
        "sdd-onboard": "cohere/command-r7b-12-2024",
        "neutral": "mistral/magistral-medium-latest",
    },
    "speed": {
        "sdd-orchestrator": "cloudflare/@cf/meta/llama-3.3-70b-instruct",
        "sdd-init": "groq/llama-3.1-8b-instant",
        "sdd-explore": "cloudflare/@cf/meta/llama-4-scout-17b-16e-instruct",
        "sdd-propose": "cloudflare/@cf/meta/llama-3.3-70b-instruct",
        "sdd-spec": "cloudflare/@cf/nvidia/llama-3.1-nemotron-70b-instruct",
        "sdd-design": "cloudflare/@cf/meta/llama-3.3-70b-instruct",
        "sdd-tasks": "cloudflare/@cf/nvidia/llama-3.1-nemotron-70b-instruct",
        "sdd-apply": "cloudflare/@cf/meta/llama-3.3-70b-instruct",
        "sdd-verify": "cloudflare/@cf/meta/llama-3.3-70b-instruct",
        "sdd-archive": "groq/openai/gpt-oss-20b",
        "sdd-onboard": "groq/llama-3.1-8b-instant",
        "neutral": "cloudflare/@cf/meta/llama-3.3-70b-instruct",
    },
    "groq": {
        "sdd-orchestrator": "groq/llama-3.3-70b-versatile",
        "sdd-init": "groq/llama-3.1-8b-instant",
        "sdd-explore": "groq/llama-3.3-70b-versatile",
        "sdd-propose": "groq/llama-3.3-70b-versatile",
        "sdd-spec": "groq/llama-3.3-70b-versatile",
        "sdd-design": "groq/llama-3.3-70b-versatile",
        "sdd-tasks": "groq/qwen/qwen3-32b",
        "sdd-apply": "groq/llama-3.3-70b-versatile",
        "sdd-verify": "groq/llama-3.3-70b-versatile",
        "sdd-archive": "groq/openai/gpt-oss-20b",
        "sdd-onboard": "groq/llama-3.1-8b-instant",
        "neutral": "groq/llama-3.3-70b-versatile",
    },
    "cerebras": {
        "sdd-orchestrator": "cerebras/qwen-3-235b-a22b-instruct-2507",
        "sdd-init": "cerebras/qwen-3-235b-a22b-instruct-2507",
        "sdd-explore": "cerebras/qwen-3-235b-a22b-instruct-2507",
        "sdd-propose": "cerebras/qwen-3-235b-a22b-instruct-2507",
        "sdd-spec": "cerebras/qwen-3-235b-a22b-instruct-2507",
        "sdd-design": "cerebras/qwen-3-235b-a22b-instruct-2507",
        "sdd-tasks": "cerebras/qwen-3-235b-a22b-instruct-2507",
        "sdd-apply": "cerebras/qwen-3-235b-a22b-instruct-2507",
        "sdd-verify": "cerebras/qwen-3-235b-a22b-instruct-2507",
        "sdd-archive": "cerebras/qwen-3-235b-a22b-instruct-2507",
        "sdd-onboard": "cerebras/qwen-3-235b-a22b-instruct-2507",
        "neutral": "cerebras/qwen-3-235b-a22b-instruct-2507",
    },
    "mistral": {
        "sdd-orchestrator": "mistral/magistral-medium-latest",
        "sdd-init": "mistral/mistral-tiny-latest",
        "sdd-explore": "mistral/mistral-small-latest",
        "sdd-propose": "mistral/magistral-medium-latest",
        "sdd-spec": "mistral/mistral-large-latest",
        "sdd-design": "mistral/magistral-medium-latest",
        "sdd-tasks": "mistral/mistral-large-latest",
        "sdd-apply": "mistral/devstral-medium-latest",
        "sdd-verify": "mistral/devstral-latest",
        "sdd-archive": "mistral/mistral-tiny-latest",
        "sdd-onboard": "mistral/ministral-3b-latest",
        "neutral": "mistral/magistral-medium-latest",
    },
    "cohere": {
        "sdd-orchestrator": "cohere/command-a-reasoning-08-2025",
        "sdd-init": "cohere/command-r7b-12-2024",
        "sdd-explore": "cohere/command-r7b-12-2024",
        "sdd-propose": "cohere/command-a-03-2025",
        "sdd-spec": "cohere/command-a-reasoning-08-2025",
        "sdd-design": "cohere/command-a-reasoning-08-2025",
        "sdd-tasks": "cohere/command-r-plus-08-2024",
        "sdd-apply": "cohere/command-a-03-2025",
        "sdd-verify": "cohere/command-a-reasoning-08-2025",
        "sdd-archive": "cohere/command-r7b-12-2024",
        "sdd-onboard": "cohere/command-r7b-12-2024",
        "neutral": "cohere/command-a-03-2025",
    },
    "gemini": {
        "sdd-orchestrator": "gemini/gemini-2.5-flash",
        "sdd-init": "gemini/gemini-2.5-flash-lite",
        "sdd-explore": "gemini/gemini-3-flash-preview",
        "sdd-propose": "gemini/gemini-2.5-flash",
        "sdd-spec": "gemini/gemini-3-flash-preview",
        "sdd-design": "gemini/gemini-2.5-flash",
        "sdd-tasks": "gemini/gemini-3-flash-preview",
        "sdd-apply": "gemini/gemini-2.5-flash-lite",
        "sdd-verify": "gemini/gemini-2.5-flash-lite",
        "sdd-archive": "gemini/gemini-2.5-flash-lite",
        "sdd-onboard": "gemini/gemini-2.5-flash-lite",
        "neutral": "gemini/gemini-2.5-flash",
    },
}


def run_opencode_model(model_id, prompt, timeout=200):
    """Run opencode run -m model_id with a simple prompt and capture output."""
    start = time.time()
    try:
        result = subprocess.run(
            ["opencode", "run", "-m", model_id, prompt],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=os.environ.get("OPENCODE_DIR", os.getcwd()),
        )
        elapsed = (time.time() - start) * 1000

        # opencode run returns 0 on success
        if result.returncode == 0:
            # Extract the assistant response from the output
            output = result.stdout.strip()
            # Heuristic: if we got any non-empty output, it worked
            if output:
                return {
                    "status": "ok",
                    "latency_ms": int(elapsed),
                    "output_len": len(output),
                    "output_preview": output[:200],
                }
            else:
                return {
                    "status": "error",
                    "error": "empty_output",
                    "latency_ms": int(elapsed),
                    "stderr": result.stderr[:300] if result.stderr else "",
                }
        else:
            stderr = result.stderr.strip() if result.stderr else ""
            stdout = result.stdout.strip() if result.stdout else ""
            # Classify common errors
            combined = (stderr + " " + stdout).lower()
            error_type = "exit_code"
            detail = f"exit={result.returncode}"
            if "request too large" in combined:
                error_type = "request_too_large"
            elif "rate" in combined and "limit" in combined:
                error_type = "rate_limit"
            elif "timeout" in combined or "timed out" in combined:
                error_type = "timeout"
            elif "auth" in combined or "401" in combined or "403" in combined:
                error_type = "auth"
            elif "not found" in combined or "404" in combined:
                error_type = "model_not_found"
            elif "abort" in combined:
                error_type = "aborted"
            elif "reasoning_content" in combined:
                error_type = "reasoning_content_bug"
            elif "chat_template_kwargs" in combined:
                error_type = "chat_template_kwargs_bug"

            return {
                "status": "error",
                "error": error_type,
                "latency_ms": int(elapsed),
                "detail": detail,
                "stderr": stderr[:500],
                "stdout": stdout[:200],
            }

    except subprocess.TimeoutExpired:
        elapsed = (time.time() - start) * 1000
        return {
            "status": "error",
            "error": "timeout",
            "latency_ms": int(elapsed),
            "detail": f"opencode run exceeded {timeout}s",
        }
    except FileNotFoundError:
        return {
            "status": "error",
            "error": "opencode_not_found",
            "detail": "opencode CLI not in PATH",
        }
    except Exception as e:
        elapsed = (time.time() - start) * 1000
        return {
            "status": "error",
            "error": "unknown",
            "latency_ms": int(elapsed),
            "detail": str(e)[:200],
        }


def run_tier_tests(tier_filter=None, timeout=200, prompt="Say exactly: OK"):
    """Test every model in every tier list through opencode run."""
    results = {}
    total_ok = 0
    total_fail = 0
    total_skip = 0
    total_tests = 0

    # Deduplicate models across tiers to avoid re-testing
    tested_models = {}  # model_id -> result

    tier_names = list(TIER_LISTS.keys())
    if tier_filter:
        tier_names = [t for t in tier_names if t in tier_filter]

    for tier_name in tier_names:
        phases = TIER_LISTS[tier_name]
        tier_results = {}

        for phase, model_id in phases.items():
            total_tests += 1

            # Reuse result if we already tested this exact model_id
            if model_id in tested_models:
                tier_results[phase] = {**tested_models[model_id], "model_id": model_id, "cached": True}
                if tested_models[model_id]["status"] == "ok":
                    total_ok += 1
                else:
                    total_fail += 1
                continue

            print(f"  Testing {tier_name}/{phase}: {model_id}...", end="", flush=True)
            result = run_opencode_model(model_id, prompt, timeout)
            result["model_id"] = model_id
            tested_models[model_id] = result
            tier_results[phase] = result

            if result["status"] == "ok":
                total_ok += 1
                print(f" OK ({result['latency_ms']}ms)")
            else:
                total_fail += 1
                print(f" FAIL ({result['error']}: {result.get('detail', '')[:60]})")

        results[tier_name] = tier_results

    summary = {"ok": total_ok, "failed": total_fail, "skipped": total_skip, "total": total_tests}
    return results, summary


def print_results(results, summary):
    """Print human-readable results grouped by tier."""
    PHASES_ORDER = [
        "sdd-orchestrator", "sdd-init", "sdd-explore", "sdd-propose",
        "sdd-spec", "sdd-design", "sdd-tasks", "sdd-apply",
        "sdd-verify", "sdd-archive", "sdd-onboard", "neutral",
    ]

    for tier_name, tier_data in results.items():
        ok_count = sum(1 for r in tier_data.values() if r["status"] == "ok")
        total_count = len(tier_data)
        status_icon = "\u2705" if ok_count == total_count else "\u274c" if ok_count == 0 else "\u26a0\ufe0f"
        print(f"\n{'='*60}")
        print(f"{status_icon} TIER: {tier_name} ({ok_count}/{total_count} OK)")
        print(f"{'='*60}")

        for phase in PHASES_ORDER:
            if phase not in tier_data:
                continue
            r = tier_data[phase]
            model_id = r.get("model_id", "?")
            status = r["status"]
            cached = " (cached)" if r.get("cached") else ""
            if status == "ok":
                latency = r.get("latency_ms", 0)
                out_len = r.get("output_len", "?")
                print(f"  \u2705 {phase:22s} {model_id:55s} {latency:>6}ms  out={out_len}{cached}")
            else:
                error = r.get("error", "unknown")
                detail = r.get("detail", "")[:60]
                stderr_snip = r.get("stderr", "")[:100]
                if error == "timeout":
                    print(f"  \u23f0 {phase:22s} {model_id:55s} TIMEOUT{cached}")
                elif error == "rate_limit":
                    print(f"  \U0001f6ab {phase:22s} {model_id:55s} RATE LIMITED{cached}")
                elif error == "request_too_large":
                    print(f"  \U0001f4e6 {phase:22s} {model_id:55s} REQUEST TOO LARGE{cached}")
                elif error == "reasoning_content_bug":
                    print(f"  \U0001f41b {phase:22s} {model_id:55s} REASONING_CONTENT BUG{cached}")
                    if stderr_snip:
                        print(f"      stderr: {stderr_snip}")
                elif error == "chat_template_kwargs_bug":
                    print(f"  \U0001f41b {phase:22s} {model_id:55s} CHAT_TEMPLATE_KWARGS BUG{cached}")
                    if stderr_snip:
                        print(f"      stderr: {stderr_snip}")
                elif error == "empty_output":
                    print(f"  \u2753 {phase:22s} {model_id:55s} EMPTY OUTPUT{cached}")
                    if stderr_snip:
                        print(f"      stderr: {stderr_snip}")
                else:
                    print(f"  \u274c {phase:22s} {model_id:55s} {error}: {detail}{cached}")
                    if stderr_snip:
                        print(f"      stderr: {stderr_snip}")

    print(f"\n{'='*60}")
    print(f"TOTAL: {summary['ok']}/{summary['total']} OK, {summary['failed']} failed, {summary['skipped']} skipped")
    print(f"{'='*60}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Verify OpenCode tier lists by testing models through opencode run"
    )
    parser.add_argument("--tier", help="Test only a specific tier (e.g., nvidia, balanced)")
    parser.add_argument("--json", action="store_true", help="Output results as JSON")
    parser.add_argument(
        "--timeout", type=int, default=200,
        help="Timeout per opencode run in seconds (default: 200)"
    )
    parser.add_argument(
        "--prompt", default="Say exactly: OK",
        help='Prompt to send (default: "Say exactly: OK")'
    )
    args = parser.parse_args()

    tier_filter = [args.tier] if args.tier else None
    results, summary = run_tier_tests(
        tier_filter=tier_filter,
        timeout=args.timeout,
        prompt=args.prompt,
    )

    if args.json:
        output = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "results": results,
            "summary": summary,
            "prompt": args.prompt,
            "timeout": args.timeout,
        }
        print(json.dumps(output, indent=2))
    else:
        print_results(results, summary)

    if summary["failed"] > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
