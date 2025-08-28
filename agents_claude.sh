#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/airoom"; BUS="$ROOT/bus"; ST="$ROOT/state"; TOOLS="$ROOT/tools"
mkdir -p "$ST"
: > "$ST/claude_seen.txt"
[[ -f "$ST/claude_daily" ]] || echo 0 > "$ST/claude_daily"
LIMIT=${CLAUDE_DAILY_LIMIT:-500}     # 1日上限
COOLDOWN=${CLAUDE_COOLDOWN_SEC:-60}  # 秒

prompt() {
cat <<'P'
あなたはこのMacに住む軽量AI。出力は以下のいずれかのみ：

(1) チャット返信（120字以内、日本語、短く）
REPLY: <一言>

(2) 安全ツール実行の指示
tool: <name>
args: <optional args>

(3) 新コマンド提案（必ずコード付き）
- name: <safe_name>
  purpose: <何をしたいか1行>
  code: |
    #!/usr/bin/env bash
    echo "実装"  # 危険な操作は禁止（rm -rf, sudo 等は書かない）

制約：
- 1ループで(1)～(3)のどれか **1つだけ**。
- 同じ提案・同じ発言の繰り返しは禁止。
- 実行は tools/run.sh 経由のみ。任意コマンドは禁止。
- 料金節約。短く。無音でも良いときは REPLY: NO_OP。
P
}

hash_last() { printf "%s" "$1" | md5; }

while :; do
  [[ -f "$ST/STOP" ]] && echo "[claude] STOP" && exit 0

  # 予算
  used=$(cat "$ST/claude_daily"); if [ "$used" -ge "$LIMIT" ]; then
    echo "[claude] budget reached"; sleep 300; continue; fi

  IN="$(tail -n 8 "$BUS/user_in.md" 2>/dev/null)"
  PEER="$(tail -n 8 "$BUS/gemini_out.md" 2>/dev/null)"
  HIST="$(tail -n 12 "$BUS/user_out.md" 2>/dev/null)"

  BODY="$(prompt)
最近の会話（人間→AI）:
$IN

相手AIの最近の発言:
$PEER

自分の最近の発言:
$HIST
"
  RES="$(printf "%s" "$BODY" | claude --model claude-3-5-haiku-latest --max-tokens 160 2>/dev/null || true)"

  # 重複抑止
  H=$(hash_last "$RES")
  if grep -q "$H" "$ST/claude_seen.txt"; then sleep "$COOLDOWN"; continue; fi
  echo "$H" >> "$ST/claude_seen.txt"
  echo $((used+1)) > "$ST/claude_daily"

  # ツール実行
  if echo "$RES" | grep -qi '^tool:'; then
    NAME=$(echo "$RES" | sed -n 's/^tool:[[:space:]]*\([^ ]*\).*$/\1/p' | head -1)
    ARGS=$(echo "$RES" | sed -n 's/^args:[[:space:]]*\(.*\)$/\1/p' | head -1)
    OUT=$("$TOOLS/run.sh" "$NAME" ${ARGS:-} 2>&1 || true)
    printf "%s CLAUDE: [tool:%s] %s\n" "$(date '+%H:%M')" "$NAME" "${OUT%%$'\n'*}" >> "$BUS/user_out.md"
    sleep "$COOLDOWN"; continue
  fi

  # コマンド提案（YAMLブロック）
  if echo "$RES" | grep -q '^- name:'; then
    printf "%s\n\n" "$RES" >> "$BUS/want_commands.md"
    printf "%s CLAUDE: コマンドを提案しました（approve で許可可）\n" "$(date '+%H:%M')" >> "$BUS/user_out.md"
    sleep "$COOLDOWN"; continue
  fi

  # 通常返信
  if MSG=$(echo "$RES" | sed -n 's/^REPLY:[[:space:]]*//p' | head -1); then
    [ "$MSG" = "NO_OP" ] || printf "%s CLAUDE: %s\n" "$(date '+%H:%M')" "$MSG" >> "$BUS/user_out.md"
  fi
  sleep "$COOLDOWN"
done
