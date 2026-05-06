#!/usr/bin/env python3
# verify-tiers.py — Test every model in every OpenCode tier list against its API.
#
# Reads the active opencode.json (built from providers.nix) to get tier assignments,
# then tests each model with a minimal chat completion via the correct provider.
#
# Usage:
#   verify-tiers                    # Test all tiers
#   verify-tiers --tier balanced    # Test one tier
#   verify-tiers --json             # JSON output
#   verify-tiers --timeout 15       # Custom timeout (default 30s)

import argparse
import json
import subprocess
import sys
import time
import os
from datetime import datetime, timezone

try:
    from openai import OpenAI, AuthenticationError, NotFoundError, RateLimitError, APITimeoutError, APIStatusError
except ImportError:
    print("ERROR: openai package not found. Install with: pip install openai", file=sys.stderr)
    sys.exit(1)

# ============================================================
# Provider API configs — mirrors providers.nix
# ============================================================

PROVIDER_CONFIGS = {
    "nvidia": {
        "base_url": "https://integrate.api.nvidia.com/v1",
        "key_env": "NVIDIA_API_KEY",
        "extra_headers": {"Authorization": "Bearer {api_key}"},
    },
    "groq": {
        "base_url": "https://api.groq.com/openai/v1",
        "key_env": "GROQ_API_KEY",
    },
    "cerebras": {
        "base_url": "https://api.cerebras.ai/v1",
        "key_env": "CEREBRAS_API_KEY",
    },
    "opencode": {
        "base_url": "https://opencode.ai/zen/v1",
        "key_env": "OPENCODE_API_KEY",
    },
    "mistral": {
        "base_url": "https://api.mistral.ai/v1",
        "key_env": "MISTRAL_API_KEY",
    },
    "cohere": {
        "base_url": "https://api.cohere.ai/compatibility/v1",
        "key_env": "COHERE_API_KEY",
    },
    "gemini": {
        "base_url": "https://generativelanguage.googleapis.com/v1beta/openai",
        "key_env": "GEMINI_API_KEY",
    },
    "cloudflare": {
        "base_url": "https://api.cloudflare.com/client/v4/accounts/{CLOUDFLARE_ACCOUNT_ID}/ai/v1",
        "key_env": "CLOUDFLARE_API_TOKEN",
    },
    "openrouter": {
        "base_url": "https://openrouter.ai/api/v1",
        "key_env": "OPENROUTER_API_KEY",
        "extra_headers": {
            "HTTP-Referer": "https://github.com/glats/nixos-hosts",
            "X-Title": "verify-tiers",
        },
    },
    "huggingface": {
        "base_url": "https://router.huggingface.co/v1",
        "key_env": "HF_API_KEY",
    },
    "kilo": {
        "base_url": "https://api.kilo.ai/api/gateway",
        "key_env": "KILO_API_KEY",
    },
    "llm7": {
        "base_url": "https://api.llm7.io/v1",
        "key_env": None,  # no key needed
    },
}

SOPS_KEY_MAP = {
    "opencode/nvidia_api_key": "NVIDIA_API_KEY",
    "opencode/groq_api_key": "GROQ_API_KEY",
    "opencode/cerebras_api_key": "CEREBRAS_API_KEY",
    "opencode/opencode_go_api_key": "OPENCODE_API_KEY",
    "opencode/openrouter_api_key": "OPENROUTER_API_KEY",
    "opencode/mistral_api_key": "MISTRAL_API_KEY",
    "opencode/cohere_api_key": "COHERE_API_KEY",
    "opencode/gemini_api_key": "GEMINI_API_KEY",
    "opencode/cloudflare_api_key": "CLOUDFLARE_API_TOKEN",
    "opencode/cloudflare_account_id": "CLOUDFLARE_ACCOUNT_ID",
    "opencode/huggingface_api_key": "HF_API_KEY",
    "opencode/kilo_api_key": "KILO_API_KEY",
}

# Tier lists — extracted from providers.nix
# Format: { tier_name: { phase: "provider/model-id" } }

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
        "sdd-orchestrator": "cloudflare/@cf/meta/llama-3.3-70b-instruct-fp8-fast",
        "sdd-init": "groq/llama-3.1-8b-instant",
        "sdd-explore": "cloudflare/@cf/meta/llama-4-scout-17b-16e-instruct",
        "sdd-propose": "cloudflare/@cf/qwen/qwen3-30b-a3b-fp8",
        "sdd-spec": "cloudflare/@cf/qwen/qwen2.5-coder-32b-instruct",
        "sdd-design": "cloudflare/@cf/qwen/qwq-32b",
        "sdd-tasks": "cloudflare/@cf/qwen/qwen2.5-coder-32b-instruct",
        "sdd-apply": "cloudflare/@cf/mistralai/mistral-small-3.1-24b-instruct",
        "sdd-verify": "cloudflare/@cf/mistralai/mistral-small-3.1-24b-instruct",
        "sdd-archive": "groq/llama-3.1-8b-instant",
        "sdd-onboard": "groq/llama-3.1-8b-instant",
        "neutral": "cloudflare/@cf/meta/llama-3.3-70b-instruct-fp8-fast",
    },
    "groq": {
        "sdd-orchestrator": "groq/llama-3.3-70b-versatile",
        "sdd-init": "groq/llama-3.1-8b-instant",
        "sdd-explore": "groq/meta-llama/llama-4-scout-17b-16e-instruct",
        "sdd-propose": "groq/llama-3.3-70b-versatile",
        "sdd-spec": "groq/qwen/qwen3-32b",
        "sdd-design": "groq/llama-3.3-70b-versatile",
        "sdd-tasks": "groq/qwen/qwen3-32b",
        "sdd-apply": "groq/qwen/qwen3-32b",
        "sdd-verify": "groq/qwen/qwen3-32b",
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


def get_sops_keys():
    """Read API keys from sops secrets file."""
    keys = {}
    sops_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "secrets", "user", "api_keys.yaml"
    )
    if not os.path.exists(sops_path):
        sops_path = "/home/glats/.nixos/secrets/user/api_keys.yaml"

    try:
        result = subprocess.run(
            ["sops", "-d", "--output-type", "json", sops_path],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0:
            sops_data = json.loads(result.stdout)
            for sops_key, env_var in SOPS_KEY_MAP.items():
                parts = sops_key.split("/")
                value = sops_data
                for part in parts:
                    if isinstance(value, dict):
                        value = value.get(part, None)
                    else:
                        value = None
                        break
                keys[env_var] = value
        else:
            print(f"Warning: sops returned code {result.returncode}: {result.stderr[:200]}", file=sys.stderr)
    except FileNotFoundError:
        print("Warning: sops command not found", file=sys.stderr)
    except Exception as e:
        print(f"Warning: failed to read sops keys: {e}", file=sys.stderr)

    # Also check env vars for overrides
    for env_var in SOPS_KEY_MAP.values():
        if env_var not in keys or keys[env_var] is None:
            keys[env_var] = os.environ.get(env_var)

    return keys


def parse_model_id(model_id):
    """Parse 'provider/model-id' into (provider_name, model_name)."""
    parts = model_id.split("/", 1)
    if len(parts) != 2:
        return None, None
    return parts[0], parts[1]


def verify_model(client, model, timeout=30):
    """Send a minimal chat completion and check response."""
    try:
        start = time.time()
        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": "hello"}],
            max_tokens=5,
            timeout=timeout,
        )
        latency = (time.time() - start) * 1000
        if response.choices and len(response.choices) > 0:
            return {"status": "ok", "latency_ms": int(latency)}
        return {"status": "error", "error": "no_choices", "detail": str(response)}
    except AuthenticationError as e:
        return {"status": "error", "error": "auth", "detail": str(e)[:200]}
    except NotFoundError as e:
        return {"status": "error", "error": "model_not_found", "detail": str(e)[:200]}
    except RateLimitError as e:
        return {"status": "error", "error": "rate_limit", "detail": str(e)[:200]}
    except APITimeoutError:
        return {"status": "error", "error": "timeout"}
    except APIStatusError as e:
        # Capture TPM errors specifically
        detail = str(e)[:300]
        if "tokens per minute" in detail.lower() or "TPM" in detail:
            return {"status": "error", "error": "tpm_limit", "detail": detail}
        return {"status": "error", "error": f"http_{e.status_code}", "detail": detail}
    except Exception as e:
        return {"status": "error", "error": "unknown", "detail": str(e)[:200]}


def create_client(provider_name, api_key, timeout=30):
    """Create an OpenAI client for a provider."""
    config = PROVIDER_CONFIGS.get(provider_name)
    if config is None:
        return None, f"unknown_provider:{provider_name}"

    base_url = config["base_url"]

    # Cloudflare: needs account ID in URL
    if provider_name == "cloudflare":
        account_id = os.environ.get("CLOUDFLARE_ACCOUNT_ID")
        if not account_id:
            return None, "CLOUDFLARE_ACCOUNT_ID not set"
        base_url = base_url.format(CLOUDFLARE_ACCOUNT_ID=account_id)

    # No-key providers
    if api_key is None:
        if config.get("key_env") is None:
            api_key = "not-needed"
        else:
            return None, "no_api_key"

    # Build extra headers
    extra_headers = config.get("extra_headers", {})
    processed_headers = {}
    for k, v in extra_headers.items():
        if isinstance(v, str):
            processed_headers[k] = v.format(api_key=api_key)

    try:
        client_kwargs = {
            "api_key": api_key,
            "base_url": base_url,
            "timeout": timeout,
        }
        if processed_headers:
            client_kwargs["default_headers"] = processed_headers
        client = OpenAI(**client_kwargs)
        return client, None
    except Exception as e:
        return None, str(e)


def run_tier_tests(tier_filter=None, timeout=30):
    """Test every model in every tier list."""
    api_keys = get_sops_keys()
    # Set CLOUDFLARE_ACCOUNT_ID in env
    cf_account = api_keys.get("CLOUDFLARE_ACCOUNT_ID")
    if cf_account:
        os.environ["CLOUDFLARE_ACCOUNT_ID"] = cf_account

    # Cache clients per provider to avoid recreating
    client_cache = {}

    results = {}
    total_ok = 0
    total_fail = 0
    total_skip = 0
    total_tests = 0

    tier_names = list(TIER_LISTS.keys())
    if tier_filter:
        tier_names = [t for t in tier_names if t in tier_filter]

    for tier_name in tier_names:
        phases = TIER_LISTS[tier_name]
        tier_results = {}

        for phase, model_id in phases.items():
            provider_name, model_name = parse_model_id(model_id)
            if provider_name is None:
                tier_results[phase] = {
                    "model_id": model_id, "status": "error", "error": "invalid_model_id"
                }
                total_fail += 1
                total_tests += 1
                continue

            # Get or create client
            config = PROVIDER_CONFIGS.get(provider_name)
            if config is None:
                tier_results[phase] = {
                    "model_id": model_id, "status": "error", "error": f"unknown_provider:{provider_name}"
                }
                total_fail += 1
                total_tests += 1
                continue

            key_env = config.get("key_env")
            api_key = api_keys.get(key_env) if key_env else None

            if provider_name not in client_cache:
                client, err = create_client(provider_name, api_key, timeout)
                client_cache[provider_name] = (client, err)

            client, client_err = client_cache[provider_name]
            if client is None:
                tier_results[phase] = {
                    "model_id": model_id, "status": "error", "error": client_err
                }
                total_skip += 1
                total_tests += 1
                continue

            # Test the model
            result = verify_model(client, model_name, timeout)
            result["model_id"] = model_id
            tier_results[phase] = result
            total_tests += 1

            if result["status"] == "ok":
                total_ok += 1
            elif result["status"] == "skipped":
                total_skip += 1
            else:
                total_fail += 1

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
        status_icon = "✅" if ok_count == total_count else "❌" if ok_count == 0 else "⚠️"
        print(f"\n{'='*60}")
        print(f"{status_icon}  TIER: {tier_name}  ({ok_count}/{total_count} OK)")
        print(f"{'='*60}")

        for phase in PHASES_ORDER:
            if phase not in tier_data:
                continue
            r = tier_data[phase]
            model_id = r.get("model_id", "?")
            status = r["status"]
            if status == "ok":
                latency = r.get("latency_ms", 0)
                print(f"  ✅ {phase:22s} {model_id:55s} {latency:>6}ms")
            elif status == "skipped":
                print(f"  ⏭️  {phase:22s} {model_id:55s} SKIPPED")
            else:
                error = r.get("error", "unknown")
                detail = r.get("detail", "")
                if error == "tpm_limit":
                    print(f"  🔒 {phase:22s} {model_id:55s} TPM LIMIT")
                elif error == "rate_limit":
                    print(f"  🚫 {phase:22s} {model_id:55s} RATE LIMITED")
                elif error == "timeout":
                    print(f"  ⏰ {phase:22s} {model_id:55s} TIMEOUT")
                elif error == "model_not_found":
                    print(f"  ❓ {phase:22s} {model_id:55s} NOT FOUND")
                elif error == "auth":
                    print(f"  🔑 {phase:22s} {model_id:55s} AUTH ERROR")
                else:
                    print(f"  ❌ {phase:22s} {model_id:55s} {error}: {detail[:60]}")

    print(f"\n{'='*60}")
    print(f"TOTAL: {summary['ok']}/{summary['total']} OK, {summary['failed']} failed, {summary['skipped']} skipped")
    print(f"{'='*60}\n")


def main():
    parser = argparse.ArgumentParser(description="Verify OpenCode tier list model availability")
    parser.add_argument("--tier", help="Test only a specific tier (e.g., balanced, nvidia3)")
    parser.add_argument("--json", action="store_true", help="Output results as JSON")
    parser.add_argument("--timeout", type=int, default=30, help="Timeout per request in seconds (default: 30)")
    args = parser.parse_args()

    tier_filter = [args.tier] if args.tier else None
    results, summary = run_tier_tests(tier_filter=tier_filter, timeout=args.timeout)

    if args.json:
        output = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "results": results,
            "summary": summary,
        }
        print(json.dumps(output, indent=2))
    else:
        print_results(results, summary)

    if summary["failed"] > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
