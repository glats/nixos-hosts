# verify-models.py — Test LLM model availability across free-tier providers.
#
# Reads API keys from sops, tests each model with a minimal chat completion,
# and reports which models actually respond.
#
# Usage:
#   verify-models                     # Full test
#   verify-models --json              # JSON output
#   verify-models --provider nvidia   # Test one provider
#   verify-models --timeout 15        # Custom timeout (default 10s)

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


PROVIDERS = {
    "nvidia": {
        "base_url": "https://integrate.api.nvidia.com/v1",
        "key_env": "NVIDIA_API_KEY",
        "extra_headers": {"Authorization": "Bearer {api_key}"},
        "models": [
            # Current (from providers.nix)
            "z-ai/glm-5.1",
            "minimaxai/minimax-m2.7",
            "deepseek-ai/deepseek-v4-flash",
            "deepseek-ai/deepseek-v4-pro",
            "nvidia/nemotron-3-super-120b-a12b",
            # Candidates from awesome-free-llm-apis
            "deepseek-ai/deepseek-r1",
            "nvidia/llama-3.1-nemotron-ultra-253b-v1",
            "nvidia/nemotron-3-nano-30b-a3b",
            "meta/llama-3.1-405b-instruct",
            "qwen/qwen2.5-72b-instruct",
            "google/gemma-4-31b",
            "mistralai/mistral-large-2-instruct",
            "moonshotai/kimi-k2-instruct",
            "qwen/qwen3-coder-480b-a35b-instruct",
        ],
    },
    "groq": {
        "base_url": "https://api.groq.com/openai/v1",
        "key_env": "GROQ_API_KEY",
        "models": [
            # Current
            "llama-3.1-8b-instant",
            "llama-3.3-70b-versatile",
            "deepseek-r1-distill-llama-70b",
            "gpt-oss-120b",
            "gpt-oss-20b",
            # Candidates
            "qwen3-32b",
            "kimi-k2-instruct",
            "llama-4-scout-17b-16e-instruct",
            "llama-4-maverick-17b-128e-instruct",
        ],
    },
    "cerebras": {
        "base_url": "https://api.cerebras.ai/v1",
        "key_env": "CEREBRAS_API_KEY",
        "models": [
            # Current
            "llama-3.1-8b",
            "llama-3.3-70b",
            "gpt-oss-120b",
            # Candidates
            "qwen-3-235b-a22b-instruct-2507",
            "zai-glm-4.7",
        ],
    },
    "opencode-zen": {
        "base_url": "https://opencode.ai/zen/v1",
        "key_env": "OPENCODE_API_KEY",
        "models": [
            "big-pickle",
            "minimax-m2.5-free",
            "mimo-v2-flash-free",
            "nemotron-3-super-free",
        ],
    },
    "openrouter": {
        "base_url": "https://openrouter.ai/api/v1",
        "key_env": "OPENROUTER_API_KEY",
        "extra_headers": {
            "HTTP-Referer": "https://github.com/glats/.nixos",
            "X-Title": "verify-models",
        },
        "models": [
            "deepseek/deepseek-r1-0528:free",
            "deepseek/deepseek-chat-v3-0324:free",
            "qwen/qwen3.6-plus:free",
            "qwen/qwen3-coder-480b-a35b:free",
            "meta-llama/llama-4-scout:free",
            "meta-llama/llama-4-maverick:free",
            "meta-llama/llama-3.3-70b-instruct:free",
            "google/gemma-4-31b-it:free",
            "nvidia/nemotron-3-super-120b-a12b:free",
            "openai/gpt-oss-120b:free",
            "minimax/minimax-m2.5:free",
            "mistralai/devstral-2512:free",
        ],
    },
    "mistral": {
        "base_url": "https://api.mistral.ai/v1",
        "key_env": "MISTRAL_API_KEY",
        "models": [
            "mistral-small-4",
            "mistral-medium-3",
            "mistral-large-3",
            "open-mistral-nemo",
            "codestral",
        ],
    },
    "cohere": {
        "base_url": "https://api.cohere.com/v2",
        "key_env": "COHERE_API_KEY",
        "note": "Cohere v2 API may NOT be OpenAI-compatible — test with OpenAI SDK, may need fallback",
        "models": [
            "command-a",
            "command-r-plus",
            "command-r",
            "command-r7b",
        ],
    },
    "gemini": {
        "base_url": "https://generativelanguage.googleapis.com/v1beta/openai",
        "key_env": "GEMINI_API_KEY",
        "models": [
            "gemini-2.5-flash",
            "gemini-2.5-flash-lite",
        ],
    },
    "github": {
        "base_url": "https://models.inference.ai.azure.com",
        "key_env": "GITHUB_TOKEN",
        "models": [
            "gpt-4.1",
            "gpt-4.1-mini",
            "gpt-4o",
            "o3-mini",
            "o4-mini",
            "Llama-4-Scout-17B-16E",
            "Llama-4-Maverick-17B-128E",
            "Meta-Llama-3.3-70B",
            "DeepSeek-R1",
            "Mistral-Small-3.1",
        ],
    },
    "cloudflare": {
        "base_url": "https://api.cloudflare.com/client/v4/accounts/{CLOUDFLARE_ACCOUNT_ID}/ai/v1",
        "key_env": "CLOUDFLARE_API_TOKEN",
        "note": "Needs account_id in URL — require CLOUDFLARE_ACCOUNT_ID env var",
        "models": [
            "@cf/meta/llama-3.3-70b-instruct-fp8-fast",
            "@cf/meta/llama-3.1-8b-instruct-fp8-fast",
            "@cf/meta/llama-4-scout-17b-16e-instruct",
            "@cf/mistralai/mistral-small-3.1-24b-instruct",
            "@cf/qwen/qwq-32b",
        ],
    },
    "ovhcloud": {
        "base_url": "https://oai.endpoints.kepler.ai.cloud.ovh.net/v1",
        "key_env": None,  # No API key needed for anonymous tier
        "models": [
            "Meta-Llama-3_3-70B-Instruct",
            "Meta-Llama-3_1-8B-Instruct",
            "DeepSeek-R1-Distill-Llama-70B",
            "Qwen3-32B",
            "Qwen3-Coder-30B-A3B-Instruct",
        ],
    },
    "siliconflow": {
        "base_url": "https://api.siliconflow.cn/v1",
        "key_env": "SILICONFLOW_API_KEY",
        "models": [
            "Qwen/Qwen3-8B",
            "deepseek-ai/DeepSeek-R1-0528-Qwen3-8B",
            "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B",
            "THUDM/glm-4-9b-chat",
        ],
    },
    "llm7": {
        "base_url": "https://api.llm7.io/v1",
        "key_env": None,  # No key needed for basic access
        "models": [
            "deepseek-r1-0528",
            "deepseek-v3-0324",
            "gemini-2.5-flash-lite",
            "gpt-4o-mini",
            "mistral-small-3.1-24b",
            "qwen2.5-coder-32b",
        ],
    },
    "kilo-code": {
        "base_url": "https://api.kilo.ai/api/gateway",
        "key_env": "KILO_API_KEY",
        "models": [
            "bytedance-seed/dola-seed-2.0-pro:free",
            "x-ai/grok-code-fast-1:optimized:free",
            "nvidia/nemotron-3-super-120b-a12b:free",
            "arcee-ai/trinity-large-thinking:free",
            "openrouter/free",
        ],
    },
    "zai-zhipu": {
        "base_url": "https://open.bigmodel.cn/api/paas/v4",
        "key_env": "ZAI_API_KEY",
        "models": [
            "glm-4.7-flash",
            "glm-4.5-flash",
            "glm-4.6v-flash",
        ],
    },
    "huggingface": {
        "base_url": "https://api-inference.huggingface.co/v1",
        "key_env": "HF_API_KEY",
        "models": [
            "Meta-Llama-3.1-8B-Instruct",
            "Mistral-7B-Instruct-v0.3",
            "Mixtral-8x7B-Instruct-v0.1",
            "Phi-3.5-mini-instruct",
            "Qwen2.5-7B-Instruct",
        ],
    },
}

SOPS_KEY_MAP = {
    "opencode/nvidia_api_key": "NVIDIA_API_KEY",
    "opencode/groq_api_key": "GROQ_API_KEY",
    "opencode/cerebras_api_key": "CEREBRAS_API_KEY",
    "opencode/openrouter_api_key": "OPENROUTER_API_KEY",
    "opencode/mistral_api_key": "MISTRAL_API_KEY",
    "opencode/cohere_api_key": "COHERE_API_KEY",
    "opencode/gemini_api_key": "GEMINI_API_KEY",
    "opencode/github_token": "GITHUB_TOKEN",
    "opencode/cloudflare_api_token": "CLOUDFLARE_API_TOKEN",
    "opencode/cloudflare_account_id": "CLOUDFLARE_ACCOUNT_ID",
    "opencode/siliconflow_api_key": "SILICONFLOW_API_KEY",
    "opencode/kilo_api_key": "KILO_API_KEY",
    "opencode/zai_api_key": "ZAI_API_KEY",
    "opencode/hf_api_key": "HF_API_KEY",
    "opencode/opencode_api_key": "OPENCODE_API_KEY",
}


def get_sops_keys():
    """Read API keys from sops secrets file."""
    keys = {}
    sops_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "secrets", "user", "api_keys.yaml")
    if not os.path.exists(sops_path):
        # Try alternative path
        sops_path = "/home/glats/.nixos/secrets/user/api_keys.yaml"

    try:
        result = subprocess.run(
            ["sops", "-d", "--output-type", "json", sops_path],
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0:
            sops_data = json.loads(result.stdout)
            for sops_key, env_var in SOPS_KEY_MAP.items():
                # Navigate nested keys like "opencode/nvidia_api_key"
                parts = sops_key.split("/")
                value = sops_data
                for part in parts:
                    if isinstance(value, dict):
                        value = value.get(part, None)
                    else:
                        value = None
                        break
                if value:
                    keys[env_var] = value
                else:
                    keys[env_var] = None
        else:
            print(f"Warning: sops returned code {result.returncode}: {result.stderr[:200]}", file=sys.stderr)
    except FileNotFoundError:
        print("Warning: sops command not found", file=sys.stderr)
    except json.JSONDecodeError as e:
        print(f"Warning: failed to parse sops JSON: {e}", file=sys.stderr)
    except subprocess.TimeoutExpired:
        print("Warning: sops command timed out", file=sys.stderr)
    except Exception as e:
        print(f"Warning: failed to read sops keys: {e}", file=sys.stderr)

    # Also check env vars for overrides
    for env_var in SOPS_KEY_MAP.values():
        if env_var not in keys or keys[env_var] is None:
            keys[env_var] = os.environ.get(env_var)

    return keys


def get_env_or_none(key):
    """Get environment variable or None if not set."""
    return os.environ.get(key)


def verify_model(client, model, timeout=10):
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
        return {"status": "error", "error": "auth", "detail": str(e)}
    except NotFoundError as e:
        return {"status": "error", "error": "model_not_found", "detail": str(e)}
    except RateLimitError as e:
        return {"status": "error", "error": "rate_limit", "detail": str(e)}
    except APITimeoutError:
        return {"status": "error", "error": "timeout"}
    except APIStatusError as e:
        return {"status": "error", "error": f"http_{e.status_code}", "detail": str(e)}
    except Exception as e:
        return {"status": "error", "error": "unknown", "detail": str(e)}


def create_client(provider_name, provider_config, api_key, timeout=10):
    """Create an OpenAI client configured for the provider."""
    base_url = provider_config["base_url"]

    # Special handling for cloudflare - needs account ID in URL
    if provider_name == "cloudflare":
        account_id = get_env_or_none("CLOUDFLARE_ACCOUNT_ID")
        if account_id:
            base_url = base_url.format(CLOUDFLARE_ACCOUNT_ID=account_id)
        else:
            return None, "CLOUDFLARE_ACCOUNT_ID not set"

    # Handle providers that don't need API keys
    if api_key is None:
        if provider_config.get("key_env") is None:
            # No key needed - use placeholder
            api_key = "not-needed"
        else:
            return None, "no_api_key"

    # Build extra headers if specified
    extra_headers = provider_config.get("extra_headers", {})
    # Substitute {api_key} placeholder in headers
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


def run_tests(providers_filter=None, timeout=10, json_output=False):
    """Run verification tests across all (or filtered) providers."""
    api_keys = get_sops_keys()
    results = {}
    total_ok = 0
    total_failed = 0
    total_skipped = 0
    total_models = 0

    provider_names = list(PROVIDERS.keys())
    if providers_filter:
        provider_names = [p for p in provider_names if p in providers_filter]

    for provider_name in provider_names:
        provider_config = PROVIDERS[provider_name]
        models = provider_config["models"]
        key_env = provider_config.get("key_env")
        api_key = api_keys.get(key_env) if key_env else None

        # Check if we have necessary credentials
        if provider_name == "cloudflare":
            if not get_env_or_none("CLOUDFLARE_ACCOUNT_ID"):
                results[provider_name] = {"error": "CLOUDFLARE_ACCOUNT_ID not set", "models": {}}
                total_skipped += len(models)
                continue

        if api_key is None and key_env is not None:
            results[provider_name] = {"error": "no_api_key", "models": {}}
            for model in models:
                results[provider_name]["models"][model] = {"status": "skipped", "error": "no_api_key"}
                total_skipped += 1
            continue

        client, client_error = create_client(provider_name, provider_config, api_key, timeout)
        if client is None:
            results[provider_name] = {"error": client_error, "models": {}}
            for model in models:
                results[provider_name]["models"][model] = {"status": "error", "error": client_error}
                total_failed += 1
            continue

        results[provider_name] = {"models": {}}

        for model in models:
            total_models += 1
            model_result = verify_model(client, model, timeout)
            results[provider_name]["models"][model] = model_result

            if model_result["status"] == "ok":
                total_ok += 1
            elif model_result["status"] == "skipped":
                total_skipped += 1
            else:
                total_failed += 1

    summary = {
        "ok": total_ok,
        "failed": total_failed,
        "skipped": total_skipped,
        "total": total_models
    }

    return results, summary


def print_text_results(results, summary):
    """Print results in human-readable format."""
    print()

    for provider_name, provider_data in results.items():
        print(f"=== {provider_name.upper()} ===")

        if "error" in provider_data and provider_data["error"] == "no_api_key":
            print("  WARNING: No API key configured — skipping")
            print()
            continue
        elif "error" in provider_data:
            print(f"  ERROR: {provider_data['error']}")
            print()
            continue

        models = provider_data.get("models", {})
        for model_name, model_result in models.items():
            status = model_result.get("status", "unknown")
            if status == "ok":
                latency = model_result.get("latency_ms", 0)
                print(f"  OK: {model_name} ({latency}ms)")
            elif status == "skipped":
                print(f"  SKIP: {model_name} — no API key")
            else:
                error = model_result.get("error", "unknown")
                print(f"  FAIL: {model_name} — {error}")

        print()

    print(f"Summary: {summary['ok']}/{summary['total']} models OK, {summary['failed']} failed, {summary['skipped']} skipped")
    print()


def print_json_results(results, summary):
    """Print results in JSON format."""
    output = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "results": results,
        "summary": summary
    }
    print(json.dumps(output, indent=2))


def main():
    parser = argparse.ArgumentParser(description="Verify LLM model availability across providers")
    parser.add_argument("--json", action="store_true", help="Output results as JSON")
    parser.add_argument("--provider", help="Test only a specific provider (e.g., nvidia)")
    parser.add_argument("--timeout", type=int, default=10, help="Timeout per request in seconds (default: 10)")
    args = parser.parse_args()

    providers_filter = [args.provider] if args.provider else None
    results, summary = run_tests(providers_filter=providers_filter, timeout=args.timeout)

    if args.json:
        print_json_results(results, summary)
    else:
        print_text_results(results, summary)

    # Exit with error code if any tests failed
    if summary["failed"] > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
