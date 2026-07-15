# モデル対応表（能力クラス → 実モデル）— モデル名の正典（例外 = claudex 関数のショートカット・DR節に注記）

> エージェント定義は能力クラスのみ宣言し `model: inherit`（または `opus` 等のエイリアス）にとどめる。
> オーケストレーター（メインセッション）は本表を引いて Agent 呼出時の model パラメータで指定する。
> モデル交代時は**本表を起点に**書き換える（バージョン番号を各所に pin しない。例外 = claudex 関数のショートカット名・DR節の注記どおり同時更新）。

| 能力クラス | 用途 | 現行モデル |
|---|---|---|
| high-risk | 設計・金銭・セキュリティ・本番影響のある実装 | `opus` |
| implementation | 定型実装・UI・テスト追加 | `sonnet` |
| mechanical | 機械的修正・検索・整形 | `haiku` |
| adversarial-review | 敵対レビュー（実装には使わない＝独立性） | Codex GPT-5.6系（複雑度サブ表で選択・下記） |
| orchestration | セッション本体 | セッション既定（/model で選択） |

## 能力クラス決定表（オーケストレーターが**呼出し前**に判定。エージェントは判断しない）
| 条件（いずれか該当） | クラス |
|---|---|
| 決済・認証・migration・PII・セキュリティ・設計判断 | high-risk |
| 既存パターンに沿う実装・UI・テスト追加・小リファクタ | implementation |
| リネーム・整形・検索・一括置換・ドキュメント微修正 | mechanical |
| コードレビュー・敵対的検証の依頼 | adversarial-review（Codex。実装には使わない） |
| **判定に迷う・複数該当** | **high-risk（昇格）** |

## adversarial-review（Codex）複雑度サブ表
基本は4択（sol / terra / luna / 5.5）から対象の複雑さで選ぶ:
| 複雑度 | 例 | Codexモデル | 指定方法 |
|---|---|---|---|
| 軽微 | CSS・文言・設定・数行diff・ドキュメントのレビュー | `gpt-5.6-luna`（Fast枠） | 呼出時に明示指定（MCP=`model`パラメータ / CLI=`--model`） |
| 標準 | 中規模実装の差分レビュー・通常のコードレビュー | `gpt-5.6-terra`（Balanced枠） | 同上 |
| 重量 | 設計/計画レビュー・認証/決済/DB/セキュリティ/本番影響・複雑実装 | `gpt-5.6-sol`（最上位枠） | 同上 |
| fallback | 5.6系が stall・未対応・不調のとき | `gpt-5.5`（前世代） | 明示指定・**その呼出し限り**（下記） |

- **fallback は sticky にしない**: fallback 発動は**そのエラーの1回限り**。次回の呼出しは必ず本来枠から再試行する。障害を記録する時は「日付＋再確認条件」付きにし、無期限の定石として書かない
- **400 "requires a newer version" 系はモデル障害でなくCLI起因**: fallback の前に `npm i -g @openai/codex@latest` を先に試す
- **判定に迷う・複数該当 → 重量（`gpt-5.6-sol` 明示指定）へ昇格**
- 全枠明示指定なので、世代交代時は本表の4行を書き換える（`~/.codex/config.toml` の既定も合わせて更新推奨＝指定漏れ時の受け皿）
- **配線**: code-reviewer agent へは**呼出しプロンプト内で** Codex モデルを指示する（agent は入力で指定されたモデルを codex-rescue へ `--model` としてパススルーする）。指定が無ければモデル未指定で実行される

## デュアルレビュー Claude レッグ サブ表
code-reviewer agent の frontmatter は `model: opus`（既定・pin しない）のまま、
**重量案件のみ Agent 呼出時の model パラメータで上位モデルに上書き**する（Codex サブ表と対称の呼出時明示方式）:
| 複雑度 | 例 | Claudeモデル | 指定方法 |
|---|---|---|---|
| 標準 | デュアルに乗る通常案件の差分レビュー | `opus`（最新Opus自動追従） | frontmatter 既定＝上書き不要 |
| 重量 | 設計/計画レビュー・認証/決済/DB/セキュリティ/本番影響・最終レビュー | `fable`（Fable 5・提供中のみ） | Agent 呼出時に `model: fable` |

- 軽微案件はそもそもデュアルに乗せない（レビュー濃淡ルール＝小変更は Claude 単独 or /code-review）
- 上位モデルの提供終了時は重量行を `opus` に戻す（`grep -i fable ~/.claude/model-tiers.md` で棚卸し）
- 上位モデルは枠消費が大きい点に留意（迷ったら標準=opus で開始し、Critical が疑われる時だけ上位で再走でもよい）

## DRフォールバックレーン: claudex（CLIProxyAPI）

Claude（Anthropic API/サブスク/モデル移行期）が使えない時に、**Claude Code ハーネスごと GPT バックエンドで動かす**避難経路。
セットアップはキットの `cliproxy` コンポーネント（README「GPTバックエンドレーン」参照）。
- 起動: `claudex [モデル]`（`~/.zshrc` 関数）。`claudex`=gpt-5.6-sol 既定／`claudex terra`／`claudex luna`／`claudex 5.5`
- 例外注記: claudex のモデル名ショートカット（sol/terra/luna/5.5）は `~/.zshrc` の関数側に実装がある — GPT 世代交代時は本表とあわせて **claudex 関数とキット README の使用例**も更新する
- **素の `claude` からの切替は構造的に不可**（`ANTHROPIC_BASE_URL` は起動時のみ読込。1セッション混在には Claude サブスク認証のプロキシ通しが必要＝規約違反なので行わない）
- スモークテスト: 月1で `claudex -p "1+1" ` ＋ツール1本（DR は検証されて初めて DR）
- **禁止: CLIProxyAPI の `-claude-login`（Anthropic OAuth 取込）は絶対に使わない**（Anthropic 規約違反・BAN 実績あり。この構成の安全性は「Anthropic OAuth 不使用・GPT 側のみプロキシ」の分離が根拠）

## モデル交代ランブック
1. 本表を書き換える（正典を分散させない。例外 = claudex 関数のショートカット名は DR 節の注記どおり同時更新）
2. 固定入力で回帰確認: 対象クラスの既存テストスイート＋直近代表タスク1件を再実行し、
   **受入条件・規則違反・検証結果**を比較（出力一致比較はしない）
3. 問題があれば fallback＝当該クラスを `opus` 固定＋人間確認ポイント追加
   （**退役済みモデルへの rollback は不可能**という前提で運用する）
4. 交代日・後継モデル・回帰結果を作業記録に残す
