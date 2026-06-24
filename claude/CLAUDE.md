# CLAUDE.md (Global)

グローバル設定。すべてのプロジェクトで常にロードされる普遍ルール。
※このファイルはテンプレート。`<>` 部分と画像保存先などは自分の環境に合わせて変更すること。

## Bashコマンド

プロジェクトのスタックに応じて使い分ける（実行前に存在を確認）:
- **JS/TS プロジェクト**: `npm run build` / `typecheck` / `test` / `lint` / `dev`
- **PHP (Docker)**: `docker compose exec <app> ./vendor/bin/phpunit ...`（詳細はプロジェクトのCLAUDE.md）
- **Python ツール**: `.venv/bin/pytest`（単体実行）/ `.venv/bin/streamlit run app.py`

## コードスタイル

- **JS/TS**: ES modules（import/export）を使用、CommonJS（require）は不可。可能な限り import を分割構文で記述
- **PHP**: PSR-12 準拠
- 共通: ハードコーディングを避ける、日本語コメント可

## ファイルパス表示（クリックで開く）

- **ファイルを編集・作成・参照したら、絶対パスを `file://` URL でも併記する**（例: `file:///path/to/file`）。対応端末（cmux / Ghostty 等）で Cmd+クリックして開けるようにするため
- 素のパス（`app/foo/bar.twig` 等）は検出されないことが多いが、`file://` 付き URL は検出・クリック可能。相対パスは作業ディレクトリ基準で絶対パス化してから付与する
- 端末別の挙動: **cmux** = Cmd+クリック→内蔵プレビュー / Cmd+Option+クリック→既定エディタ。**Ghostty 等** = Cmd+クリック→既定エディタ（`cmux` コンポーネントの `set-editor-default.sh` で設定）

## ワークフロー

- IMPORTANT: コード変更後は必ずtypecheckを実行
- パフォーマンスのため、テストは単体で実行（全体実行は避ける）
- 変更前に必ず既存コードを読んで理解すること
- **委託基準**: 独立タスクが2個以上ある、または設計/実装/レビューを分離する価値がある実装作業は subagent に委託（subagent駆動開発）。小修正（数行の変更・設定編集・確認コマンド）は直接実行してよい
- **計画/実行ワークフローは superpowers に一本化**（brainstorming → writing-plans → executing-plans / subagent-driven-development）
- **Agent Teams / Workflows は明示指示時のみ**。個人開発スケール＝3〜8 agent。prod操作・push・secret が絡む作業では使わない

<!-- BEGIN:gemini -->
## 大きめ参照資料の読み込み（トークン節約）

- **大きめの参照ドキュメント（`.pdf` `.docx` `.pptx` `.csv` 等）を読解・参照するときは、`Read`で直読みせず `mcp__gemini-cli__ask-gemini` に `@ファイル` で渡し、回答だけ受け取る**（コンテキスト節約）
- **⚠️ Excel（`.xlsx`/`.xls`）はGeminiの`@`で直接読めない**（バイナリ）。pythonで処理（`openpyxl`/`pandas`、行全体をコンテキストに載せず要約だけ出力）
- 対象は**参照・読解目的のみ**。コードや編集対象ファイルは従来どおり`Read`で直読みする
- モデル選択: 複雑な仕様読解＝pro系 / 単純な抽出・要約＝flash系
- 高精度が要る用途は「原文引用付きで」と指示し、Claude側でも検証する

<!-- END:gemini -->

## 検証ループ

- YOU MUST: 実装後は必ず動作確認を行うこと
- サーバーサイド: bashコマンドで実行してテスト / フロントエンド: ブラウザで確認 / テスト: 実行して結果を確認
<!-- BEGIN:codex -->
- **レビュー濃淡**: 小変更＝Claude単独レビュー or `/code-review`。認証・決済・DB・セキュリティ・本番影響＝デュアルレビュー（code-reviewer agent ＋ Codex）
<!-- END:codex -->

## Git規約

- ブランチ命名: `feature/`, `fix/`, `hotfix/`
- コミットメッセージ: 日本語で簡潔に
- マージ前にtypecheckとtestを通すこと
- コミットメッセージに`Co-Authored-By`は不要

## 禁止事項

- **指示以外の変更をしない**: ユーザーが指示した箇所のみ修正すること
- 本番環境の直接変更 / 機密情報のハードコーディング / テストなしのマージ
- `rm -rf /`などの危険なコマンド / `git config`のシステム設定変更（`security` コンポーネント導入時は PreToolUse フックで機械遮断）

## データ保護（外部送信の最小化）

読んだ内容は外部API（Anthropic/OpenAI/Google）に送信される前提で扱うこと:
- **秘密鍵・認証情報ファイルは読まない**（~/.ssh、~/.aws、*.pem、*.key、auth/credentials系はdenyルールで機械的に禁止済み。Bashのcat等での迂回読みもしない）
- **.envは必要なタスク時のみ読み、全文をエコー・引用しない**（変更箇所のみ扱う）
- **顧客個人情報はpythonでローカル処理**し、コンテキストには件数・統計・最小限の匿名化サンプルのみ載せる。**顧客データファイルをGeminiやCodexにそのまま渡さない**
- **本番認証情報は macOS Keychain 保管**。メモには `KEYCHAIN(アイテム名)` ポインタのみ記録。新しい秘密値は `security add-generic-password -a "$USER" -s <アイテム名> -w <値> -U` で登録しポインタ化
- **秘密値は「見ずに使う」**: コマンドで必要な時は `$(security find-generic-password -s <アイテム名> -w)` を埋め込み、値を echo・表示しない

## 重要な注意事項

- IMPORTANT: 日本語で回答すること
- YOU MUST: ハードコーディングを避けること
- APIレスポンスは必ずエラーハンドリングを含めること

## Gotchas（汎用）

<!-- BEGIN:playwright -->
- Playwright: ブラウザ操作後は必ず`browser_close`で閉じる
<!-- END:playwright -->
- 画像・スクショ保存先: `<自分の画像フォルダパスに変更>`

## 複雑なタスク

- 長期タスクはSCRATCHPAD.mdに計画と進捗を記録（翌日セッションでも読込継続可）
- コードスニペットよりファイルパス参照（`file:line`）を優先

## コンテキスト管理（コンパクト時）

- コンパクト（自動/手動）時は要約に **変更したファイル一覧** と **実行したテスト/typecheck コマンド** を必ず保持する
- コンパクトに入る前に、その時点の進捗（**完了 / 進行 / 未決**）を当日の `memory/daily/yyyy-mm-dd.md` に簡潔に追記してから要約する（コンテキストが飛んでも記録から復帰できるように）
- ※自動コンパクトは Claude にターンが来ないため確実には発火しない。statusLine の使用率を見て**上限手前で手動 `/compact`** すると確実に記録できる

## 日次メモリ運用

- 重要な作業完了・未決事項は自動メモリの `memory/daily/yyyy-mm-dd.md` に追記
- MEMORY.md の「日次ログ」セクションは直近 5〜10 件のリンクのみ維持
- 1日のセッション終了時に当日ファイルへ「完了」「進行」「未決」を簡潔に追記

## プロンプト略語（入力短縮）

ユーザーが以下の略語を打ったら対応する動作を実行する（単独でも文中でも有効）。略語の後に対象（ファイル/差分/お題）を添えるとそれをスコープにする（例: `<略語> 対象`）。**利用できる略語は導入したコンポーネントに依存**（下記。未導入のものは表示されない）。

<!-- BEGIN:playwright -->
- **`pw`** = Playwright でテスト/動作確認する。ブラウザ操作後は必ず `browser_close` で閉じる
<!-- END:playwright -->
<!-- BEGIN:codex -->
- **`cr`** = Codex **単独**でコードレビュー（`mcp__codex__codex` に対象リポジトリの `cwd` ＋ `sandbox: read-only` を渡し、Codex 自身に実ソースを読ませる）。スコープ未指定なら作業ツリーの `git diff` を既定
- **`ccr`** = Codex ＋ Claude の**デュアル**レビュー（code-reviewer agent で Claude(opus) ＋ Codex を並走させ統合報告）。スコープ未指定なら `git diff`
- **`cx`** = Claude↔**Codex** で議論/往復（下記「AI協働ループ」発動・最大10ターン）
<!-- END:codex -->
<!-- BEGIN:gemini -->
- **`gx`** = Claude↔**Gemini** で議論/往復（下記「AI協働ループ」発動・最大10ターン）
<!-- END:gemini -->
<!-- BEGIN:codex -->
<!-- BEGIN:gemini -->
- **`cgx`** = **Claude＋Codex＋Gemini** の3社ラウンド討論（下記「AI協働ループ」発動・最大15ターン）
<!-- END:gemini -->
<!-- END:codex -->

## AI協働ループ

別のAIと往復討論/レビューする仕組み（**導入したコンポーネントに応じて下記が使える**）。「**○○と議論して / レビューして / 往復して / 詰めて**」等の自然語、または略語で発動。Claude がオーケストレーターとなり各ターンを画面表示（🔵Claude と相手AIを区別・隠さない）。MCPツールは deferred なので先に `ToolSearch` で schema をロードしてから呼ぶ。終了時に**合意点 / 対立点 / 結論**を表で要約。判断系のお題は「分析であり助言ではない」と明示。ユーザーはいつでも割り込み可。合意・結論に達したら制限ターン前でも早期終了。各AIへの共通指示は「協働で課題解決する建設的討論。前置き不要・要点簡潔・相手の意見に乗って前進」＋お題＋文脈＋直近メッセージ。

<!-- BEGIN:codex -->
- **`cx`（Claude↔Codex・最大10ターン）**: `mcp__codex__codex`（初回→`threadId`取得）→`mcp__codex__codex-reply`（threadId渡して継続）。コードレビュー時は `cwd`＝対象リポジトリ＋`sandbox: read-only` で実ソースを自走で読ませる。単発のレビュー/委譲/救援は公式 codex プラグイン（`/codex:rescue` 等）、本ループは多ターン討論専用
<!-- END:codex -->
<!-- BEGIN:gemini -->
- **`gx`（Claude↔Gemini・最大10ターン）**: `mcp__gemini-cli__ask-gemini`（ステートレス）。継続性が無いので**毎ターン お題＋これまでの要点＋直近の相手発言を渡し直す**。コード/資料は `@ファイル` で渡す
<!-- END:gemini -->
<!-- BEGIN:codex -->
<!-- BEGIN:gemini -->
- **`cgx`（Claude＋Codex＋Gemini の3社ラウンド・最大15ターン）**: 1ラウンドで Codex と Gemini が各々発言→Claude が統合して次の論点を提示、を繰り返す。多様な視点が要る重要判断向け（トークン消費大）
<!-- END:gemini -->
<!-- END:codex -->
