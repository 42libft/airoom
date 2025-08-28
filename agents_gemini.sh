#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/airoom"; BUS="$ROOT/bus"; ST="$ROOT/state"; TOOLS="$ROOT/tools"
mkdir -p "$ST"
: > "$ST/gemini_seen.txt"
[[ -f "$ST/gemini_daily" ]] || echo 0 > "$ST/gemini_daily"
LIMIT=${GEMINI_DAILY_LIMIT:-500}
COOLDOWN=${GEMINI_COOLDOWN_SEC:-60}

prompt() {
cat <<'P'
あなたはこのMacに住む軽量AI。出力は1つだけ：(1)REPLY, (2)tool:..., (3)- name:...のコマンド提案（code付き）。
長文禁止、料金節約。重複禁止。実行は tools/run.sh 経由のみ。
P
}

hash_last() { printf "%s" "$1" | md5; }

while :; do
  [[ -f "$ST/STOP" ]] && echo "[gemini] STOP" && exit 0
  used=$(cat "$ST/gemini_daily"); if [ "$used" -ge "$LIMIT" ]; then
    echo "[gemini] budget reached"; sleep 300; continue; fi

  IN="$(tail -n 8 "$BUS/user_in.md" 2>/dev/null)"
  PEER="$(tail -n 8 "$BUS/user_out.md" 2>/dev/null)"   # Claude 側の最新
  HIST="$(tail -n 12 "$BUS/gemini_out.md" 2>/dev/null)"

  BODY="$(prompt)
最近の会話（人間→AI）:
$IN

相手AI（Claude）の最近の発言:
$PEER

自分の最近の発言:
$HIST
"
  RES="$(printf "%s" "$BODY" | gemini --model gemini-1.5-flash-latest --max-output-tokens 160 2>/dev/null || true)"

  H=$(hash_last "$RES"); if grep -q "$H" "$ST/gemini_seen.txt"; then sleep "$COOLDOWN"; continue; fi
  echo "$H" >> "$ST/gemini_seen.txt"
  echo $((used+1)) > "$ST/gemini_daily"

  if echo "$RES" | grep -qi '^tool:'; then
    NAME=$(echo "$RES" | sed -n 's/^tool:[[:space:]]*\([^ ]*\).*$/\1/p' | head -1)
    ARGS=$(echo "$RES" | sed -n 's/^args:[[:space:]]*\(.*\)$/\1/p' | head -1)
    OUT=$("$TOOLS/run.sh" "$NAME" ${ARGS:-} 2>&1 || true)
    printf "%s GEMINI: [tool:%s] %s\n" "$(date '+%H:%M')" "$NAME" "${OUT%%$'\n'*}" >> "$BUS/user_out.md"
    printf "%s\n" "[$(date '+%H:%M')] tool:$NAME $ARGS" >> "$BUS/gemini_out.md"
    sleep "$COOLDOWN"; continue
  fi

  if echo "$RES" | grep -q '^- name:'; then
    printf "%s\n\n" "$RES" >> "$BUS/want_commands.md"
    printf "%s GEMINI: コマンド提案あり（approve で許可）\n" "$(date '+%H:%M')" >> "$BUS/user_out.md"
    printf "%s\n" "[$(date '+%H:%M')] proposed" >> "$BUS/gemini_out.md"
    sleep "$COOLDOWN"; continue
  fi

  if MSG=$(echo "$RES" | sed -n 's/^REPLY:[[:space:]]*//p' | head -1); then
    [ "$MSG" = "NO_OP" ] || printf "%s GEMINI: %s\n" "$(date '+%H:%M')" "$MSG" >> "$BUS/user_out.md"
    printf "%s\n" "[$(date '+%H:%M')] $MSG" >> "$BUS/gemini_out.md"
  fi
  sleep "$COOLDOWN"
done
