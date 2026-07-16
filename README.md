# claude-code-env01 — Claude Code 環境再現キット

バイブコーディング用に整備した Claude Code 環境（2026-06 再設計版）を、別PC・別の人に再現するためのキット。

設計思想: **「安全境界を先に狭める。能力は削らず、同じ目的の入口を減らす」**

## かんたん導入: Claude Code に任せる（推奨・初心者向け）

シェルを触らず、**Claude Code 自身にセットアップさせる**方法。エンジニアでなくてもOK。

1. [Claude Code](https://code.claude.com/) をインストールして起動する
2. このリポジトリを `git clone` し、そのフォルダで Claude Code を開く（または「このリポジトリを読んで」と渡す）
3. **「このリポジトリを読んで、私の環境をセットアップして」** と頼む

すると Claude Code が `SETUP.md`（エージェント向け手順書）に従い、**あなたの今の環境と比較して、足りない/良くなる項目だけを1つずつ「○○を導入しますか？ YES/NO」と聞きながら**導入します。非エンジニアにも分かる説明付きで、既存設定は壊さずマージします。あなたの環境の方が優れている項目は無理に入れません。

> 仕組み: リポジトリ直下の `CLAUDE.md` が入口で、Claude Code に `SETUP.md` を読ませて実行させる。

以下は**自分で手動インストールしたい人向け**の説明です。

## 前提

- macOS（Keychain・Homebrew・BSD date 前提。Linuxはスクリプト要調整）
- **必須**: [Claude Code](https://code.claude.com/) インストール済み・ログイン可能 / `python3`（`xcode-select --install`）/ `git`
- **コンポーネント依存**: `jq`（security/statusline）/ `node`+`npx`（playwright/context7/fetchjs）/ `brew`（gitleaks 等の自動導入）
- 任意: Codex CLI（`npm i -g @openai/codex`）/ Gemini CLI（レビュー・議論・資料読解委譲を使う場合）
- Git が無い人は GitHub の「Code → Download ZIP」で取得し展開してもよい

## セットアップ（コンポーネント選択式）

```bash
git clone https://github.com/tkk-whiplash/claude-code-env01.git
cd claude-code-env01
./setup.sh                              # 対話形式: 1つずつ Y/n で選択
./setup.sh --minimal                    # 初心者最小構成（security/statusline/cmux）
./setup.sh --yes                        # 全部入り（質問なし・managed を除く）
./setup.sh --yes --skip=codex,gemini    # Codex/Gemini連携なしで全部入り
```

**既存設定は壊さない**: `setup.sh` は既存の `~/.claude/settings.json` を**マージ**（deny は union、hooks/plugins/env は無いものだけ追加、既存 statusLine は尊重）。`CLAUDE.md`/`settings.json` は実行前に `.bak-<日時>` へ退避。**前提（python3 等）が無い場合は何も書かずに中断**するので中途半端な状態にならない。

**全く同じ環境を強制しない設計**: 選択に応じて settings.json・CLAUDE.md（該当セクション）・agents/skills/MCP が動的に組み立てられる。Codex を外すと、プラグイン・MCP・デュアルレビューagent・協働ループ規約・略語がまとめて除外され、残骸も残らない。

> 課金注意: 出力エフォート（`effortLevel`）は配布デフォルトに**含めない**（各自 `/effort` で調整）。`env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`（Agent Teams 実験機能）は **`agent-teams` を選んだ時のみ** settings.json に入る（未選択なら入らない）。

| キー | コンポーネント | 外すとどうなる |
|---|---|---|
| `superpowers` | 計画/TDDワークフローskill群 | プラグイン宣言から除外 |
| `lsp` | PHP/Python LSP | 同上 |
| `mdmgmt` | CLAUDE.md管理 | 同上 |
| `codex` | Codex連携一式（略語 `cr`/`ccr`/`cx`、AI協働ループの Codex 部分） | プラグイン+MCP+code-reviewer agent+`cr`/`ccr`/`cx`/`cgx` を除外 |
| `gemini` | Gemini連携（大型資料の読解委譲＋議論ループ `gx`） | MCP+資料委譲節+`gx`/`cgx` を除外 |
| `context7` | ライブラリ最新ドキュメントMCP | MCP登録をスキップ |
| `playwright` | ブラウザ操作MCP（`--isolated`＝複数セッション同時実行可・略語 `pw` 含む） | MCP登録と CLAUDE.md の略語 `pw` をスキップ |
| `security` | セキュリティフック（破壊的コマンド遮断＋設定改ざん防止） | PreToolUseフック+settings登録をスキップ |
| `statusline` | ステータスライン（コンテキスト/レート制限/Codex使用量等） | スクリプト+settings登録をスキップ |
| `cmux` | クリック→ファイル/エディタ起動設定（cmuxは内蔵プレビュー＋エディタ既定、Ghostty等はエディタ既定のみ） | 配置をスキップ |
| `staleness` | 棚卸しリマインダー | フック+settings登録+基準日をスキップ |
| `gitleaks` | 秘密情報コミット防止 | brew+共通フックをスキップ |
| `zip` / `fetchjs` | 各スキル | スキルコピーをスキップ |
| `agent-teams` | Agent Teams（複数AI並列＝env+teammateMode=auto+workflow警告抑制） | settings登録をスキップ |
| `notifications` | 入力待ち/完了のデスクトップ・プッシュ通知 | settings登録をスキップ |
| `remote-control` | 起動時にweb/モバイルからの操作を有効化 | settings登録をスキップ |
| `model-tiers` | モデル対応表（能力クラス→実モデル・**レビュー複雑度サブ表**=Codex/Claude両レッグ） | `~/.claude/model-tiers.md` 配置をスキップ |
| `cliproxy` | **GPTバックエンドレーン**（CLIProxyAPI＋`claudex`関数＝ChatGPTサブスクでGPT系モデルをClaude Codeから起動・DR用） | brew導入+conf構成+`~/.zshrc`追記をスキップ |
| `managed` | **組織強制設定**（配布端末/非エンジニア向け・root所有 managed-settings＝認証情報deny＋bypass封鎖を変更不能に） | 設置をスキップ（**--yes でも入らない**＝対話実行での明示opt-inのみ） |

※ permissions の deny ルール（`~/.codex/auth.json` 含む）は選択に関わらず常に入る — 未導入ツールへのdenyは無害で、後から導入した時の保護になるため。

実行後の手動ステップは setup.sh の最後に表示される（プラグイン信頼承認・各CLI認証・プレースホルダ編集など）。

## 何が入るか

| パス | 内容 |
|---|---|
| `claude/CLAUDE.md` | グローバルルール（委託基準・レビュー濃淡・データ保護・**file:// パス併記**＝cmux/Ghostty でクリック起動・Codexループ等）。`<>` は要カスタマイズ |
| `claude/settings.json` | permissions（auto＋**秘密鍵denyルール**）・プラグイン宣言（superpowers / codex / LSP）・棚卸しフック登録 |
| `claude/agents/code-reviewer.md` | Claude＋Codexデュアルレビューagent（`model: opus` エイリアス既定・重量案件は呼出時にmodel上書き＝model-tiers.md参照） |
| `claude/model-tiers.md` | 能力クラス→実モデル対応表＋レビュー複雑度サブ表（Codex=luna/terra/sol/5.5・Claude=opus/上位モデル）＋claudex運用規約 |
| `claude/cliproxy/claudex.zsh` | `claudex [sol\|terra\|luna\|5.5]`＝CLIProxyAPI経由でGPT系モデルのClaude Codeを起動するzsh関数（キーはKeychain参照） |
| `claude/managed-settings.json` | 組織強制設定テンプレート（`/Library/Application Support/ClaudeCode/` に root 所有で設置＝ユーザー/プロジェクト設定・Claude自身から上書き不能。中身は認証情報deny＋`disableBypassPermissionsMode` のみ） |
| `claude/skills/plugin-zip/` | 配布ZIP作成スキル（テスト確認→白ラベル検査→構造検証） |
| `claude/skills/fetch-js-page/` | JSレンダリング必須ページのPlaywright取得スキル |
| `claude/hooks/harness-staleness-check.sh` | **棚卸しリマインダー**: 前回棚卸しから90日以上でセッション冒頭に警告（期限内は無音） |
| `claude/hooks/block-destructive-commands.sh` | **破壊的コマンド遮断**（PreToolUse:Bash）: `rm -rf /`〜`$HOME`/システムパス・`dd of=/dev/`・`mkfs`・fork bomb・`git config --system` を deny、`curl\|sh`・**コマンド位置の `sudo`**（多行・軽量ラッパー・絶対パス含む）を ask。単純な文字列中の sudo は誤検知しないが、**区切り文字を含む引用文字列は安全側に ask になりうる**。プロジェクト内 `rm -rf *` 等は素通り |
| `claude/hooks/protect-settings.sh` | **設定改ざん防止**（PreToolUse:Edit/Write）: settings.json/CLAUDE.md への `skipAutoPermissionPrompt`・`enableAllProjectMcpServers:true`・`ANTHROPIC_BASE_URL` 等の権限破壊キー注入を deny |
| `claude/statusline-command.sh` | **ステータスライン**: コンテキスト使用率（色付きバー）・Claude 5時間レート制限・Codex使用量（リセット時刻＋残り時間）・**稼働中エージェント**（このセッションの `in_progress` タスク数＋経過時間。`⚙`、20分超は黄色でstall警告）・モデル名・gitブランチ・カレントディレクトリ（要 `jq`） |
| `claude/cmux/cmux.json` | **cmux クリック設定**: `openSupportedFilesInCmux=true`（Cmd+クリック→内蔵プレビュー）。`~/.config/cmux/` に配置（**cmux検出時のみ**。Ghostty等ではスキップ） |
| `claude/cmux/set-editor-default.sh` | コードを**選択したエディタ**で開く `duti` 既定ハンドラ設定（端末非依存＝cmux/Ghostty両対応）。setup時にエディタ名を選択。VS Code選択時はtwig拡張も導入 |
| `git-hooks/` ＋ `install-git-hook.sh` | **gitleaks pre-commit**: 秘密情報のコミットを機械的にブロック |

MCP（setup.shが登録）: codex / gemini-cli / context7 / playwright。Playwright は `--isolated` 付きで登録され、**複数セッションの同時ブラウザ操作が可能**（デフォルトの永続プロファイルはロックで1インスタンスに制限される）。

## 何が入らないか（意図的）

- **memory/（作業メモリ）** — 個人の作業文脈のため除外。各自の環境で自然に育つ
- **~/.claude.json・認証情報** — 各自でログイン・認証
- **秘密値** — Keychain運用（下記）。このリポジトリには一切含まない
- **settings.local.json** — マシン固有のpermissionsは各自で育てる

## セキュリティ設計（このキットの肝）

1. **denyルール**: ~/.ssh・~/.aws・*.pem・*.key・auth/credentials系に加え、本番/秘密系env（`.env.production` 等）・`secrets/**`・`*.p12`/`*.pfx`/`*.keystore`・`~/.kube`・`~/.docker/config.json`・`~/.npmrc`・`~/.pypirc` の Read を機械的に禁止。**`.env` の扱い**: ホームの `~/.env` のみ deny、プロジェクト直下の `.env`/`.env.local` は編集ワークフロー維持のため**許可**（本番系 `.env.production` 等は deny）
2. **破壊的コマンド遮断フック**（`security`）: 致命的な `rm -rf`・`dd of=/dev/`・`mkfs`・fork bomb・`git config --system` を PreToolUse で deny、`curl|sh` を ask。指示（遵守率は確率的）ではなくフックで決定論的に止める。**完全防御ではなく事故防止層**（変数経由 `A=/; rm -rf "$A"` やセパレータ跨ぎは検知外）。`jq` 不在時は fail-closed で `ask` に倒す
3. **設定改ざん防止フック**（`security`）: settings.json/CLAUDE.md への権限無効化キー（`skipAutoPermissionPrompt` 等）注入を deny。CVE-2025-59536/2026-21852 クラスの「設定経由の権限破壊」への自衛。**限界**: Edit/Write 経由のみ検知。**Bash 経由（`echo >> settings.json` 等）の書き込みは検知範囲外**（浅い自衛層）＝`.claude/` と CLAUDE.md は git diff のレビュー対象に含めること。**確実に固定したい配布端末では `managed` コンポーネント**（root所有 managed-settings）が上位の防御層になる
4. **Keychain運用**: 秘密値は `security add-generic-password -a "$USER" -s <名前> -w <値> -U` で保管し、メモには `KEYCHAIN(名前)` ポインタのみ。使う時は `$(security find-generic-password -s <名前> -w)` で**値を表示せずコマンドに注入**（AIのコンテキスト＝外部API送信に載せない）
5. **gitleaks pre-commit**: コミット時に秘密情報を自動スキャン。誤検知時は `SKIP_GITLEAKS=1 git commit ...`、恒久除外は `.gitleaksignore`。※ **gitleaks 未導入の環境ではスキャンされず通過（fail-open）**＝全コミット不能を避ける設計。確実にしたい人は gitleaks を導入すること
6. **運用ルール**（CLAUDE.mdデータ保護節）: .env全文エコー禁止・顧客個人情報はローカルpython処理・外部AIに顧客データファイルを渡さない
7. **組織強制層**（`managed`・任意）: `/Library/Application Support/ClaudeCode/managed-settings.json`（root所有）は**全設定の最上位でユーザー側から変更不能**。配布端末・非エンジニア向けに認証情報 deny と `--dangerously-skip-permissions` の封鎖を固定する。**制限し過ぎない方針**: 中身は「読む正当理由がないファイルのdeny」と「bypass封鎖」のみ＝日常作業の確認回数は増えない。sudo は破壊的コマンドフック側で **ask**（遮断でなく確認1回）。外すのも `sudo rm` 一発で可逆

## 運用の型

- **小変更** → Claude単独 or `/code-review`、**重要変更**（認証/決済/DB/本番影響） → デュアルレビュー（code-reviewer agent）
- **レビューのモデル選択** → 対象の複雑さで切替（`model-tiers` 参照）: Codexレッグ=軽微`luna`/標準`terra`/重量`sol`/fallback`5.5`、Claudeレッグ=標準`opus`（既定）/重量は呼出時に上位モデルへ上書き
- **計画/実行** → superpowers（brainstorming → writing-plans → subagent駆動）
- **大型資料の読解** → Gemini委譲（トークン節約）
- **90日ごと** → 棚卸しリマインダーが発火 → プラグイン・MCP・permissionsを点検し `~/.claude/harness-audit-date` を更新

## GPTバックエンドレーン（`cliproxy`）— Claude が使えない時の避難経路

**ChatGPT Plus/Pro サブスクの Codex OAuth** をローカルプロキシ（[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)・homebrew-core収載）に持たせ、Claude Code を `ANTHROPIC_BASE_URL`（Anthropic 公式のゲートウェイ接続機構）でそこへ向けることで、**superpowers・メモリ・エージェント等のハーネスごと GPT 系モデルで動かせる**。

```bash
claudex            # gpt-5.6-sol で Claude Code 起動
claudex terra      # gpt-5.6-terra
claudex luna       # gpt-5.6-luna
claudex 5.5        # gpt-5.5
claude             # 通常の Claude（プロキシ非経由・普段どおり）
```

- セットアップ: `cliproxy` コンポーネント選択 → 手動2ステップ（`cliproxyapi -codex-login` でブラウザ認証 → `brew services start cliproxyapi`）
- モデル切替: `/model` ピッカーは**素のまま**（Default/Opus/Sonnet/Haiku）。スロット割当 env（`ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU,FABLE}_MODEL`）により **Opus→Sol / Sonnet→Terra / Haiku→Luna** に解決される＝ピッカー切替が実質GPT切替（実測検証済み: `--model opus` 起動でバックエンド着弾モデル=`gpt-5.6-sol`）。切替は **`s` キー（セッション限定）推奨**。effort は公式サフィックス書式 `claudex "gpt-5.6-sol(xhigh)"`
- 仕組み: CLIProxyAPI 公式推奨の「env のみ」構成（BASE_URL＋AUTH_TOKEN＋スロット割当＋`CLAUDE_CODE_SUBAGENT_MODEL`）。**discovery / availableModels / settings 自動生成は不使用**（Anthropic 公式が非Claudeモデルのゲートウェイルーティングをサポート外と明言しており、ピッカー統合は既知不具合が多いため 2026-07-16 に全撤去）。すべて claudex 関数内のみ＝素の `claude` は不変
- 保険: `_claudex_model_guard`（起動前後で settings.json の model を退避・GPT名/難読名の汚染を検知したら自動復元）。`/model gpt-5.6-luna` 直打ちが Enter 相当でグローバル保存される公式仕様（v2.1.153+）への対策
- 位置づけは **DR（Claude 障害・移行期の避難）**。常用は非推奨（tool-calling 翻訳層・prompt cache 不使用のため品質は Claude ネイティブに劣る）
- 規約面: Claude 側は素の認証のまま・**Anthropic OAuth をプロキシに通さない**のが安全性の根拠（2026-02 の Anthropic 規約変更に非抵触）。OpenAI 側は Codex OAuth＋ローカルプロキシ方式を許容（OpenClaw が公式採用）
- **🚫 CLIProxyAPI の `-claude-login` は絶対に使わない**（Anthropic 規約違反・BAN 実績あり）
- 設定は `127.0.0.1` bind・conf 権限600・ローカルキーは Keychain（`cliproxyapi-local-key`）。本キットの設定改ざん防止フックは settings.json への `ANTHROPIC_BASE_URL` 注入を deny するが、claudex は **シェル環境変数方式**なので保護と両立する
