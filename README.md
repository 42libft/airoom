# AI Room – README

この環境は **「PCの中に住んでいるAI同居人」** を再現する仕組みです。  
Claude と Gemini が常駐して会話し、人間ともやりとりしながら「コマンド」を実行します。  

---

## 📂 ディレクトリ構成
```
~/airoom/
  bus/        # 会話と申請のやりとり
    user_in.md      人間→AI の発言
    user_out.md     AI→人間 の返答
    want_commands.md    AIが提案したコマンド
    approved_commands.md 承認済みのコマンド
    rejected_commands.md 却下されたコマンド
  tools/      # 実行可能なコマンド
    run.sh    ツール実行ランナー
    hello.sh  (例: Helloを出すツール)
  state/      # STOPスイッチや日次カウンタ
  work/       # AIが好きに開発できるサンドボックス
```

---

## 🚀 起動と停止
### 起動
```bash
tmux new -ds claude-room ~/airoom/agents_claude.sh
tmux new -ds gemini-room ~/airoom/agents_gemini.sh
```

### 停止
```bash
touch ~/airoom/state/STOP
```
（もう一度起動する時は `rm ~/airoom/state/STOP`）

---

## 💬 人間との会話
### 話しかける
```bash
sayto おはよう
```

### 返事を見る
```bash
tail -f ~/airoom/bus/user_out.md
```

---

## 🛠️ コマンドの提案と承認フロー
1. **AIが提案**  
   - `bus/want_commands.md` に `- name: ... purpose: ... code: | ...` の形で書かれる  

2. **人間が承認／却下**  
   - 承認するとき  
     ```bash
     approve <name>
     ```
   - 却下するとき  
     ```bash
     reject <name>
     ```

3. **自動追加**  
   - 承認されたコマンドは `~/airoom/tools/<name>.sh` として生成される  
   - 以降、AIは `tool: <name>` を呼んで実行できる  

---

## 🧯 安全ガード
- **作業領域は ~/airoom 配下のみ**  
- `rm -rf`, `sudo`, `/etc`, `/System` など危険コードは自動拒否  
- **STOPファイル**で即時停止可能  
- **日次コール制限**あり（上限超過で強制スリープ）  

---

## 🔎 テスト例
### AIに「hello」コマンドを作らせた後に承認：
```bash
approve hello
~/airoom/tools/hello.sh
# => Hello from test tool!
```

---

## 📝 まとめ
- **会話** → `sayto` コマンド＋`user_out.md` を tail  
- **コマンド提案** → `want_commands.md` にAIが書く  
- **承認／却下** → `approve NAME` or `reject NAME`  
- **停止** → `touch ~/airoom/state/STOP`  

これで「PC内にAIが住んでいる」体験を安全に楽しめます。


---

## 👀 観測モード (observe)
AIたちのやりとりやツール実行をリアルタイムに「暮らしを覗く」ように観測できます。  
色分けされてターミナルに流れてくるので、生活感が出ます。

### 起動
```bash
~/airoom/observe
```

### 色分けルール
- **シアン (YOU)** : 人間からの発言 (`sayto`)
- **緑 (CLAUDE)** : Claudeの発言
- **マゼンタ (GEMINI)** : Geminiの発言
- **黄 (TOOL)** : ツール実行イベント
- **青 (INFO)** : システム情報やその他

### 停止
`Ctrl+C` で終了します。

> 補足: `tmux` セッションで `observe` を常駐させておくと便利です。

