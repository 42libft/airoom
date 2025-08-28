#!/usr/bin/env bash
set -euo pipefail
# 標準入力で受け取ったシェルコードを検査し、危険なら非0で終了
CODE="$(cat)"

deny() { echo "[validator] DENY: $1" >&2; exit 1; }

# 危険ワード（必要に応じて増やせる）
BAD_REGEXES=(
  '(^|[^A-Za-z])rm[[:space:]]+-rf'
  '(^|[^A-Za-z])sudo[[:space:]]'
  '(^|[^A-Za-z])ssh[[:space:]]'
  '(^|[^A-Za-z])scp[[:space:]]'
  '(^|[^A-Za-z])curl[[:space:]].*\|[[:space:]]*sh'   # curl | sh
  '(^|[^A-Za-z])wget[[:space:]].*\|[[:space:]]*sh'
  '>/dev/(sda|disk|rdisk)'
  '\bkillall\b'
  '\bdefaults[[:space:]]write\b.*com.apple'          # macの全体設定変更
)

for rx in "${BAD_REGEXES[@]}"; do
  if echo "$CODE" | LC_ALL=C grep -Eqi "$rx"; then
    deny "pattern: $rx"
  fi
done

# 危険な絶対パスへの書き込みを禁止（/etc, /System 配下）
if echo "$CODE" | grep -Eq '(^|[[:space:]])/(etc|System)\b'; then
  deny "writes outside sandbox"
fi

# 成功ならコードをそのまま出力して次へ渡す
printf "%s" "$CODE"
