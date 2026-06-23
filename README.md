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
./setup.sh --yes                        # 全部入り（質問なし）
./setup.sh --yes --skip=codex,gemini    # Codex/Gemini連携なしで全部入り
```

**既存設定は壊さない**: `setup.sh` は既存の `~/.claude/settings.json` を**マージ**（deny は union、hooks/plugins/env は無いものだけ追加、既存 statusLine は尊重）。`CLAUDE.md`/`settings.json` は実行前に `.bak-<日時>` へ退避。**前提（python3 等）が無い場合は何も書かずに中断**するので中途半端な状態にならない。

**全く同じ環境を強制しない設計**: 選択に応じて settings.json・CLAUDE.md（該当セクション）・agents/skills/MCP が動的に組み立てられる。Codex を外すと、プラグイン・MCP・デュアルレビューagent・協働ループ規約・略語がまとめて除外され、残骸も残らない。

> 課金注意: 出力エフォート（`effortLevel`）は配布デフォルトに**含めない**（各自 `/effort` で調整）。`env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`（Agent Teams 実験機能）は settings.json に入る。不要なら導入後に削除可。

| キー | コンポーネント | 外すとどうなる |
|---|---|---|
| `superpowers` | 計画/TDDワークフローskill群 | プラグイン宣言から除外 |
| `claude-mem` | 永続メモリ | 同上 |
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

※ permissions の deny ルール（`~/.codex/auth.json` 含む）は選択に関わらず常に入る — 未導入ツールへのdenyは無害で、後から導入した時の保護になるため。

実行後の手動ステップは setup.sh の最後に表示される（プラグイン信頼承認・各CLI認証・プレースホルダ編集など）。

## 何が入るか

| パス | 内容 |
|---|---|
| `claude/CLAUDE.md` | グローバルルール（委託基準・レビュー濃淡・データ保護・**file:// パス併記**＝cmux/Ghostty でクリック起動・Codexループ等）。`<>` は要カスタマイズ |
| `claude/settings.json` | permissions（auto＋**秘密鍵denyルール**）・プラグイン宣言（superpowers / claude-mem / codex / LSP）・棚卸しフック登録 |
| `claude/agents/code-reviewer.md` | Claude＋Codexデュアルレビューagent（`model: opus` エイリアス＝バージョンpinしない） |
| `claude/skills/plugin-zip/` | 配布ZIP作成スキル（テスト確認→白ラベル検査→構造検証） |
| `claude/skills/fetch-js-page/` | JSレンダリング必須ページのPlaywright取得スキル |
| `claude/hooks/harness-staleness-check.sh` | **棚卸しリマインダー**: 前回棚卸しから90日以上でセッション冒頭に警告（期限内は無音） |
| `claude/hooks/block-destructive-commands.sh` | **破壊的コマンド遮断**（PreToolUse:Bash）: `rm -rf /`〜`$HOME`/システムパス・`dd of=/dev/`・`mkfs`・fork bomb・`git config --system` を deny、`curl\|sh` を ask。プロジェクト内 `rm -rf *` 等は素通り |
| `claude/hooks/protect-settings.sh` | **設定改ざん防止**（PreToolUse:Edit/Write）: settings.json/CLAUDE.md への `skipAutoPermissionPrompt`・`enableAllProjectMcpServers:true`・`ANTHROPIC_BASE_URL` 等の権限破壊キー注入を deny |
| `claude/statusline-command.sh` | **ステータスライン**: コンテキスト使用率（色付きバー）・Claude 5時間レート制限・Codex使用量（リセット時刻＋残り時間）・モデル名・gitブランチ・カレントディレクトリ（要 `jq`） |
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
3. **設定改ざん防止フック**（`security`）: settings.json/CLAUDE.md への権限無効化キー（`skipAutoPermissionPrompt` 等）注入を deny。CVE-2025-59536/2026-21852 クラスの「設定経由の権限破壊」への自衛。**限界**: Edit/Write 経由のみ検知。**Bash 経由（`echo >> settings.json` 等）の書き込みは検知範囲外**（浅い自衛層）＝`.claude/` と CLAUDE.md は git diff のレビュー対象に含めること
4. **Keychain運用**: 秘密値は `security add-generic-password -a "$USER" -s <名前> -w <値> -U` で保管し、メモには `KEYCHAIN(名前)` ポインタのみ。使う時は `$(security find-generic-password -s <名前> -w)` で**値を表示せずコマンドに注入**（AIのコンテキスト＝外部API送信に載せない）
5. **gitleaks pre-commit**: コミット時に秘密情報を自動スキャン。誤検知時は `SKIP_GITLEAKS=1 git commit ...`、恒久除外は `.gitleaksignore`。※ **gitleaks 未導入の環境ではスキャンされず通過（fail-open）**＝全コミット不能を避ける設計。確実にしたい人は gitleaks を導入すること
6. **運用ルール**（CLAUDE.mdデータ保護節）: .env全文エコー禁止・顧客個人情報はローカルpython処理・外部AIに顧客データファイルを渡さない

## 運用の型

- **小変更** → Claude単独 or `/code-review`、**重要変更**（認証/決済/DB/本番影響） → デュアルレビュー（code-reviewer agent）
- **計画/実行** → superpowers（brainstorming → writing-plans → subagent駆動）
- **大型資料の読解** → Gemini委譲（トークン節約）
- **90日ごと** → 棚卸しリマインダーが発火 → プラグイン・MCP・permissionsを点検し `~/.claude/harness-audit-date` を更新
