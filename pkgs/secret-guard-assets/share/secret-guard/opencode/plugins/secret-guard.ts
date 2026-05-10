/**
 * Secret Guard Plugin for OpenCode
 *
 * Prevents accidental secret exposure by:
 * 1. Redacting known secret patterns from bash output
 * 2. Stripping SOPS environment variables from shell env
 *
 * Note: Blocking of secret paths and sops commands is handled by
 * permissions.nix (enforceable) and SYSTEM_RULES.md (advisory).
 * This plugin provides runtime redaction as a defense-in-depth layer.
 */

import type { Plugin } from '@opencode-ai/sdk';

interface ToolExecuteAfterEvent {
  tool: string;
  args: Record<string, unknown>;
  result: unknown;
}

// Known secret patterns for redaction
const SECRET_PATTERNS = [
  // OpenAI API keys
  /sk-[a-zA-Z0-9]{48}/g,
  // Age secret keys
  /AGE-SECRET-KEY-[A-Z0-9]{58}/g,
  // Generic API keys (common patterns)
  /[A-Z0-9]{32,64}/g,
  // Bearer tokens
  /Bearer\s+[A-Za-z0-9\-_~]+/g,
  // AWS access keys
  /AKIA[0-9A-Z]{16}/g,
];

function redactSecrets(text: string): string {
  let result = text;
  for (const pattern of SECRET_PATTERNS) {
    result = result.replace(pattern, '[REDACTED]');
  }
  return result;
}

export const secretGuard: Plugin = {
  name: 'secret-guard',

  hooks: {
    // Note: We intentionally do NOT use tool.execute.before for blocking.
    // The opencode plugin API does not guarantee that returning an error object
    // from before hooks is handled gracefully. Blocking is handled by
    // permissions.nix (enforceable) and SYSTEM_RULES.md (advisory).
    // This plugin focuses on redaction and env sanitization only.

    'tool.execute.after': (event: ToolExecuteAfterEvent) => {
      // Redact secrets in bash output
      if (event.tool === 'bash' && typeof event.result === 'string') {
        return redactSecrets(event.result);
      }
      return event.result;
    },

    'shell.env': (env: Record<string, string>) => {
      // Strip SOPS environment variables
      const cleaned = { ...env };
      delete cleaned['SOPS_AGE_KEY'];
      delete cleaned['SOPS_AGE_KEY_FILE'];
      return cleaned;
    },
  },
};