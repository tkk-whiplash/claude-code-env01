# CLIProxyAPI 経由の Claude Code（GPT系バックエンド・DRレーン）。キーは Keychain 参照（平文非保持）
# 禁止: cliproxyapi の -claude-login（Anthropic OAuth取込）は絶対に使わない（規約違反・BAN実績あり。
#       この構成の安全性は「GPT側OAuthのみプロキシに持たせ、Claude側認証は素のまま」の分離が根拠）
#
# 構成方針（2026-07-16 再構築）: CLIProxyAPI 公式推奨の「env のみ」構成。
#   discovery / availableModels / settings 自動生成は使わない（Anthropic 公式が非Claudeモデルの
#   ゲートウェイルーティングをサポート外と明言しており、ピッカー統合は不具合の巣だったため全撤去）。
# 使い方: claudex（既定=sol）/ claudex terra / claudex luna / claudex 5.5 / claudex 5.4
#         effort は公式サフィックス書式: claudex "gpt-5.6-sol(xhigh)"。残り引数は claude へ透過
# モデル切替: /model ピッカーは素のまま（Default/Opus/Sonnet/Haiku）。スロット割当により
#   Opus→Sol / Sonnet→Terra / Haiku→Luna に解決される＝ピッカー切替が実質GPT切替。
#   サブエージェントは CLAUDE_CODE_SUBAGENT_MODEL により Sol 固定（スロット割当はメインのみ）。
#   切替は「s」キー（セッション限定）推奨。Enter はグローバル settings.json に保存される:
#   GPT名の直打ち保存は下のガードが自己修復するが、Opus/Sonnet 等の正当なエイリアス保存は
#   復元対象外（素の claude の既定が変わったままになる）— Enter を使ったら自分で戻すこと。
# ⚠ claudex の同時多重起動は非対応（ガードの退避ファイルが1本のため）

# グローバル model 汚染ガード（pre=起動前に正常値を退避＋前回クラッシュ分を復元 / post=終了後に汚染検知→復元）
# 汚染判定: gpt-* または難読クローク名（-dd- 含み）。素の Claude モデル名（claude-fable-5 等）は正当値として触らない
# 退避形式: JSON {"settings_existed": bool, "has_model": bool, "model": str|null}
#   （settings.json が未生成の環境でも「model キー無し」として退避→復元可能。破損時のみ何もしない）
_claudex_model_guard() {
  python3 - "$1" "$HOME/.claude/settings.json" "$HOME/.claude/.claudex-global-model.bak" <<'PY'
import json, os, sys, tempfile
mode, settings, bak = sys.argv[1], sys.argv[2], sys.argv[3]
def polluted(v):
    return isinstance(v, str) and (v.startswith("gpt-") or "-dd-" in v)
def atomic_write(path, text):
    fd, tmp = tempfile.mkstemp(prefix=".claudex-guard.", dir=os.path.dirname(path))
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.replace(tmp, path)
def load_bak():
    try:
        d = json.load(open(bak))
        return d if isinstance(d, dict) and "has_model" in d else None
    except Exception:
        return None
# settings 読込。ファイル不在は「未生成」として扱い、破損（パース不能）のみ何もしない
data, exists = None, os.path.exists(settings)
if exists:
    try:
        data = json.load(open(settings))
    except Exception:
        sys.exit(0)  # 破損 settings には触らない（保険は効かない旨 README に明記）
cur = data.get("model") if isinstance(data, dict) else None
has_cur = isinstance(data, dict) and "model" in data
if not (has_cur and polluted(cur)):
    if mode == "pre":  # 正常状態を退避（settings 不在・model キー無しも状態として記録）
        atomic_write(bak, json.dumps(
            {"settings_existed": exists, "has_model": has_cur, "model": cur if has_cur else None},
            ensure_ascii=False) + "\n")
    sys.exit(0)
# 汚染検知 → 退避から復元
saved = load_bak()
if saved is None:
    print("claudex: ⚠ グローバル model が GPT 名のまま退避が見つかりません。"
          "~/.claude/settings.json の model を手動で確認してください", file=sys.stderr)
    sys.exit(0)
if saved["has_model"]:
    data["model"] = saved["model"]
    label = repr(saved["model"])
else:
    data.pop("model", None)
    label = "(キー削除)"
atomic_write(settings, json.dumps(data, ensure_ascii=False, indent=2) + "\n")
print(f"claudex: グローバル model を復元しました（{cur!r} → {label}）", file=sys.stderr)
PY
}

claudex() {
  local model="gpt-5.6-sol"
  case "$1" in
    sol|terra|luna) model="gpt-5.6-$1"; shift ;;
    5.5|5.4) model="gpt-$1"; shift ;;
    gpt-*) model="$1"; shift ;;   # "gpt-5.6-sol(xhigh)" 等の effort サフィックス込みも透過
  esac
  # Keychain からローカルキー取得。失敗時は空トークンで起動せず即中断（値は表示しない）
  local tok
  tok=$(security find-generic-password -a "$USER" -s cliproxyapi-local-key -w 2>/dev/null)
  if [[ -z "$tok" ]]; then
    print -u2 "claudex: Keychain からキーを取得できません（cliproxyapi-local-key）。Keychain のロック解除または登録を確認してください"
    return 1
  fi
  _claudex_model_guard pre
  # スロット割当（CLIProxyAPI 公式推奨の v2 系 env）: ピッカーやサブエージェントの
  # opus/sonnet/haiku/fable 指定がそのまま GPT 系へ解決される
  ANTHROPIC_BASE_URL=http://127.0.0.1:8317 \
  ANTHROPIC_AUTH_TOKEN="$tok" \
  ANTHROPIC_DEFAULT_OPUS_MODEL='gpt-5.6-sol' \
  ANTHROPIC_DEFAULT_SONNET_MODEL='gpt-5.6-terra' \
  ANTHROPIC_DEFAULT_HAIKU_MODEL='gpt-5.6-luna' \
  ANTHROPIC_DEFAULT_FABLE_MODEL='gpt-5.6-sol' \
  CLAUDE_CODE_SUBAGENT_MODEL='gpt-5.6-sol' \
  claude --model "$model" "$@"
  local rc=$?
  # 終了後の自己修復（claude が TUI 内で SIGINT を処理するため、通常終了・/exit・二度押し Ctrl+C いずれも通る。
  # プロセス kill 等で到達しない場合も次回起動の pre で復元される）
  _claudex_model_guard post
  return $rc
}
