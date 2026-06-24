# SETUP.md — Claude Code 自動オンボーディング手順（エージェント向け）

> **このファイルは Claude Code（＝あなた、AIエージェント）が読んで実行するための手順書です。**
> ユーザーが「このリポジトリを読んで環境をセットアップして」等と言ったら、以下に厳密に従ってください。
> 人間が手動で入れる場合の説明は `README.md` / `setup.sh` を参照（このファイルとは別系統）。

---

## 絶対原則（必ず守る）

1. **既存設定を壊さない。** 必ず先にバックアップ → **マージ**（置換しない）。ユーザーの今の `settings.json`/`CLAUDE.md` の独自設定を消さない。
2. **差分だけ提案する。** ユーザーの現状を調べ、**既に入っている項目は「導入済み」と伝えてスキップ**。未導入・改善できるものだけ聞く。
3. **非エンジニアにも分かる言葉で。** 専門用語は必ずかみ砕く。1項目ずつ「○○（やさしい説明）を導入しますか？ YES/NO」で確認。
4. **不可逆・広範な変更は実行前に必ず一言断る。** 例: 既定アプリ変更(duti)、`brew install`、MCP登録。
5. **日本語で進行。** 各ステップで何をしているか短く実況する。
6. **リポジトリは「強制標準」ではなく「選択肢のメニュー」。** ユーザーの既存環境の方が優れている、または本人の用途・環境に合わない項目は**無理に入れない**。項目ごとに「これは本当にこの人にとって改善になるか？」を**その都度判断**し、ならない場合は理由を添えてスキップ（または現状維持を推奨）する。AIの役割は標準への画一化ではなく、その人の環境を**ネットで良くすること**。

---

## ステップ0: あいさつと前提把握

1. 一言あいさつし、こう聞く:「**エンジニアの方ですか？それともプログラミングは詳しくないですか？**（説明の詳しさを調整します）」
2. OS を確認: `uname -s`。このキットは **macOS 前提**（Keychain・Homebrew・BSD `date`・`duti`/`osascript`）。Linux の場合は「一部スクリプトは調整が必要」と伝え、セキュリティ/statusline 等の汎用部分のみ進める。

---

## ステップ1: 現状の検出（ユーザーの今の環境を読む）

以下を調べて記録する（後の差分算出に使う）。読み取りのみ、まだ変更しない:

- Claude Code: `claude --version`
- 既存設定: `~/.claude/settings.json`（あれば**全部読む**）、`~/.claude/CLAUDE.md` の有無と内容
- 既存の `enabledPlugins` / `hooks`（SessionStart・PreToolUse）/ `statusLine` / `permissions.deny`
- 既存スキル/エージェント: `~/.claude/skills/`・`~/.claude/agents/`
- 前提ツールの有無: `command -v brew node npx python3 jq git duti cmux codex gemini code`
- 端末種別: cmux か（`/Applications/cmux.app` の有無）、Ghostty 等か

---

## ステップ2: 差分の算出

このリポジトリの提供物（下表「コンポーネント一覧」）と、ステップ1の現状を突き合わせ、各コンポーネントを次の4つに分類:

- **導入済み**（聞かない・「もう入っています」と伝える）
- **未導入**（提案対象）
- **更新可能**（既にあるが、このキット版の方が新しい/安全 → 違いを説明して提案）
- **ユーザー側が優れている / 合わない**（提案しない。必要なら「あなたの今の設定の方が良い/合っているのでそのまま維持を勧めます」と一言）

**双方向に比較する（重要）**: 「リポジトリにあるから入れる」ではなく、**両者を見比べて本当に改善になるか**を判断する。例:
- ユーザーが既に**より厳格・より作り込まれた**フックや deny・statusline を持っている → **そのまま維持**を勧め、上書きしない。
- ユーザーの**用途に合わない**（例: PHP/Python を書かない人に `lsp`、git を使わない人に `gitleaks`、ブラウザ作業をしない人に `playwright`）→ 提案しない or 「不要そう」と伝える。
- ユーザーの環境に**前提が無く導入コストが見合わない**（例: Node を入れてまで context7 が要るか）→ 本人に判断材料を出して選ばせる。
- 競合する既存設定（別の statusLine、別の MCP playwright 設定等）がある → 勝手に置換せず、**違いを説明してどちらを使うか聞く**。

例: ユーザーの settings.json に PreToolUse フックが無ければ `security` は「未導入」。deny に `.env.production` 等が無ければ「更新可能（denyを足せる）」。逆にユーザーが独自の高度なフック群を持っていれば「ユーザー側が優れている」に分類し、push しない。

---

## ステップ3: 1項目ずつ YES/NO 確認（未導入・更新可能なものだけ）

下の「コンポーネント一覧」の**やさしい説明**を使って、1つずつ確認する。フォーマット例:

> **Playwright を導入しますか？**
> → Claude が**ブラウザを自動で操作**して、サイトの動作確認やスクリーンショット取得ができるようになります。Web制作やテストをする人に便利です。（必要: Node.js）
> **YES / NO**

- 既に入っているものは聞かない。
- 非エンジニアには「これは何の役に立つか」を1文添える。エンジニアには簡潔でよい。
- 依存ツール（jq/node 等）が必要なものは、その旨も伝える。
- まとめて聞かず**1問ずつ**。迷っている様子なら「全員におすすめ」印（下表）を案内。
- **「更新可能」項目は中立に**: 「あなたの今の○○とキットの○○はここが違います（…）。どちらにしますか？」と**両方の長短を正直に**出して選ばせる。キット版を押し付けない。ユーザー側が優れていると判断したら、その旨を伝えて現状維持を勧める。

---

## ステップ4: 前提ツールの補完

YESで選ばれた項目に必要な前提が無ければ、**何を・なぜ入れるか説明してから**導入する（実行前に確認）:

- `jq`（security/statusline に必須）: `brew install jq`
- `node`/`npx`（playwright/context7/fetch-js-page）: 案内（`brew install node` 等）
- `python3`（settings生成に使うなら）: `xcode-select --install`
- `brew` 自体が無ければ: https://brew.sh のインストールコマンドを案内
- `duti`（cmuxのエディタ既定設定）: `brew install duti`

---

## ステップ5: 導入（マージ。既存を壊さない）

1. **バックアップ**: 既存ファイルがあるときのみ退避。例 `[ -f ~/.claude/settings.json ] && cp ~/.claude/settings.json ~/.claude/settings.json.bak-$(date +%Y%m%d-%H%M%S)`（`CLAUDE.md` も同様。初回＝ファイル不在ならスキップ）。
2. **スクリプト配置**: 選ばれた `claude/hooks/*.sh`・`claude/statusline-command.sh` を `~/.claude/hooks/`・`~/.claude/` にコピーし `chmod +x`。
3. **settings.json は既存にマージ**（置換禁止）。`jq` か `python3` で、実 `$HOME` を展開した絶対パスで書く。
   - ※ `setup.sh` も**同じマージ方式**（既存を保持して追加分だけ反映）に修正済み。回答を `--skip` に落として `./setup.sh --yes --skip=<未選択>` を実行してもよい（既存設定は壊れない）。手動マージする場合は以下:
   - `permissions.deny`: 既存と **union**（重複排除）。null ガード必須: `(.permissions.deny // [])`
   - `hooks.PreToolUse`/`SessionStart`: 同一 `command` が無いエントリだけ**追加**（既存フックは消さない）
   - `statusLine`: 未設定なら追加。既に別の statusLine があれば**上書き前に確認**
   - `enabledPlugins`・`extraKnownMarketplaces`・`env`: **無いキーだけ追加**（既存値は保持）
   - top-level scalar（`teammateMode`・`skipWorkflowUsageWarning`・`inputNeededNotifEnabled`・`agentPushNotifEnabled`・`remoteControlAtStartup`）: **無いキーだけ追加**（既存値は上書きしない）
   - **アトミック書き込み**: 一時ファイルに書いて `mv`（途中失敗で settings.json を壊さない）
   - jq 例（deny union・null安全・アトミック）:
     ```bash
     jq '.permissions.deny = ((.permissions.deny // []) + $add | unique)' \
       --argjson add '["Read(**/.env.production)","Read(**/secrets/**)"]' \
       ~/.claude/settings.json > ~/.claude/settings.json.tmp \
       && mv ~/.claude/settings.json.tmp ~/.claude/settings.json
     ```
4. **CLAUDE.md**:
   - ユーザーに無ければ `claude/CLAUDE.md` を雛形として配置し、`<>`（画像保存先等）を本人用に直すよう案内。
   - 既にあれば**勝手に上書きしない**。足りない有用セクション（`file://` パス併記ルール / データ保護 / プロンプト略語 等）を提示し、「末尾に追記してよいですか？」と確認してから追記。
5. **MCP登録**（選択時、実行前に一言）: `claude mcp add -s user <name> -- ...`。**playwright は必ず `--isolated`**（複数同時実行可）: `claude mcp add -s user playwright -- npx @playwright/mcp@latest --isolated`。
6. **cmux / クリック設定**（選択時）:
   - cmux があれば `claude/cmux/cmux.json` を `~/.config/cmux/` にマージ（バックアップ後）し `cmux reload-config`。Ghostty 等なら cmux.json はスキップ。
   - 「ファイルをクリックで開くエディタは何を使いますか？（VS Code / Cursor / Zed など）」と聞き、`bash claude/cmux/set-editor-default.sh "<エディタ名>"` を**既定変更の確認を取ってから**実行。

---

## ステップ6: 動作確認

- **statusline**: `echo '{"context_window":{"used_percentage":42},"model":{"display_name":"Claude"},"workspace":{"current_dir":"'$HOME'"}}' | ~/.claude/statusline-command.sh` で1行表示されるか。
- **security フック**: ダミーJSONで `deny`/`ask` が返るか軽く確認（危険リテラルを自分のbashコマンドに直書きすると**このフック自身に止められる**ので、ペイロードはファイル経由か jq で組み立てる）。
- **MCP**: `claude mcp list`。
- 結果を簡潔に報告。

---

## ステップ7: まとめ（平易な言葉で）

- **入れたもの一覧** ＋ それぞれ一言。
- **残りの手動ステップ**を案内:
  - 「**Claude Code を再起動**すると、安全装置（フック）と画面下の表示が有効になります」
  - Codex/Gemini を入れたなら「各CLIで一度ログインが必要」
  - 「秘密のパスワードやAPIキーは、ファイルに書かず **macOS Keychain** に保存しましょう」
  - CLAUDE.md の `<>` を本人用に直す
- 「あとで設定を見直したくなったら、また『このリポジトリで見直して』と言ってください」と添える。

---

## コンポーネント一覧（YES/NO確認時はこの言葉で説明する）

| キー | やさしい説明（非エンジニア向け） | おすすめ度 | 必要なもの |
|---|---|---|---|
| **security** | Claude が**危険なコマンド**（PC全体を消す・設定を勝手に書き換える等）を実行しないようにする**安全装置（ブレーキ）** | ★全員 | jq |
| **statusline** | 画面下に「今どれくらい会話量を使ったか」「利用上限まであと何時間か」等を**常に表示** | ★全員 | jq |
| **cmux/click** | ターミナルに出るファイル名を **Cmd+クリックで開ける**ようにする（cmux/Ghostty対応） | ○便利 | (任意)duti+エディタ |
| **playwright** | Claude が**ブラウザを操作**して動作確認・スクショ取得（複数同時実行可） | Web/テストする人 | node |
| **codex** | もう一つのAI（OpenAI Codex）と連携して**コードを二重レビュー**（略語 `cr`/`ccr`/`cx`） | レビュー重視の人 | codex CLI |
| **gemini** | 大きなPDF/資料を **Gemini に読ませてトークン節約** | 大型資料を扱う人 | gemini CLI |
| **superpowers** | 計画→実装→レビューの**開発ワークフロー**（skill群） | 本格開発する人 | - |
| **lsp** | **PHP / Python** のコード補完・診断 | その言語を書く人 | - |
| **mdmgmt** | CLAUDE.md（Claudeへの指示書）の**管理支援** | 設定を育てたい人 | - |
| **context7** | **最新ライブラリの公式ドキュメント**を参照できる | ライブラリ多用の人 | node |
| **staleness** | **90日ごと**に設定の棚卸しを促すリマインダー | 長く使う人 | - |
| **gitleaks** | **秘密情報をコミットしようとすると止める** | git を使う全員 | brew |
| **zip / fetchjs** | 配布ZIP作成 / JSページ取得の補助スキル | 該当作業がある人 | (fetchjsはnode) |
| **agent-teams** | 複数のAIを**並列実行**して協調作業。`env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`＋`teammateMode=auto`＋workflow警告抑制（分割ペインは tmux/iTerm2 があれば、無ければ画面内パネルに自動フォールバック＝**tmux不要**） | 大きい作業を分担したい人 | トークン約7倍に注意 |
| **notifications** | **入力待ち**や**作業完了**をデスクトップ通知・プッシュで知らせる | 離席して待つ人 | - |
| **remote-control** | 起動時に**web/モバイルからの操作**を有効化（リモートで Claude Code を操作） | 外出先から使う人 | - |

> エージェントハーネス設定（agent-teams/notifications/remote-control）は**好みの領域**。未選択でも基本機能は完全に動く。特に `agent-teams` は実験的＆トークン消費が大きいので、必要を感じてから入れるのが無難。`remote-control` はリモート操作を開くため、セキュリティ観点で不要なら入れない。

> 迷う人には **security / statusline / cmux/click** の3つを「まず入れると安心・便利」と案内する。

---

## 重要な注意（ユーザーに伝えるべき点）

- セキュリティフックと statusline は **次回 Claude Code 起動から有効**（導入後に再起動を案内）。
- セキュリティフックは**完全防御ではなく事故防止層**。コマンド文字列に `rm -rf /` 等のリテラルが含まれると反応するため、**コミットメッセージ等での誤反応**は `git commit -F <ファイル>` で回避できる。
- 設定改ざん防止フック（`protect-settings`）は **Edit/Write/MultiEdit 経由のみ検知**。`echo >>`/`tee`/`cp` 等の **Bash 経由での settings.json/CLAUDE.md 書き込みは範囲外**（浅い自衛層）。`.claude/` と CLAUDE.md は git diff のレビュー対象に含めて補完すること。
- `duti` による既定アプリ変更・`brew install`・MCP登録は**実行前に必ず確認**を取る。
- このリポジトリには秘密情報・個人情報を**含めない**（Keychain運用）。
