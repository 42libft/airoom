#!/usr/bin/env bash
set -euo pipefail
# usage: run.sh <tool-name> [args...]
NAME="${1:?tool name required}"; shift || true
# 安全な名前のみ許可
[[ "$NAME" =~ ^[a-zA-Z0-9_-]{1,40}$ ]] || { echo "DENY bad name" >&2; exit 1; }
TOOL="$HOME/airoom/tools/$NAME.sh"
[[ -x "$TOOL" ]] || { echo "DENY no such tool: $NAME" >&2; exit 1; }

# タイムアウト実行（coreutils があれば gtimeout）
TIMEOUT=$(command -v gtimeout >/dev/null && echo gtimeout || echo timeout)
$TIMEOUT 8s "$TOOL" "$@" 2>&1 | tail -n 80
