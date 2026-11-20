#!/usr/bin/env bash
# 20-nov-2026: hook PreToolUse (matcher REPL) de Code Mode; la lógica vive en revisar_repl.py. Sale 2 si bloquea.
exec python3 -I "$(dirname "$0")/revisar_repl.py"
