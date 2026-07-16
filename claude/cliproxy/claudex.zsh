# CLIProxyAPI 経由の Claude Code（GPT系バックエンド・DRレーン）。キーは Keychain 参照（平文非保持）
# 禁止: cliproxyapi の -claude-login（Anthropic OAuth取込）は絶対に使わない（規約違反・BAN実績あり。
#       この構成の安全性は「GPT側OAuthのみプロキシに持たせ、Claude側認証は素のまま」の分離が根拠）
#
# 構成方針（2026-07-16 再構築）: CLIProxyAPI 公式推奨の「env のみ」構成。
#   discovery / availableModels / settings 自動生成は使わない（Anthropic 公式が非Claudeモデルの
#   ゲートウェイルーティングをサポート外と明言しており、ピッカー統合は不具合の巣だったため全撤去）。
# 使い方: claudex（既定=sol）/ claudex terra / claudex luna / claudex 5.5 / claudex gpt-5.4
#         effort は公式サフィックス書式: claudex "gpt-5.6-sol(xhigh)"。残り引数は claude へ透過
# モデル切替: /model ピッカーは素のまま（Default/Opus/Sonnet/Haiku）。スロット割当により
#   Opus→Sol / Sonnet→Terra / Haiku→Luna に解決される＝ピッカー切替が実質GPT切替。
#   切替は「s」キー（セッション限定）推奨。Enter は settings.json に保存されるが、
#   ピッカーに GPT 名が出ない構成なので保存されるのは正当な値のみ（素の claude は壊れない）。
#   ⚠ /model gpt-5.6-luna 等の直打ちだけは GPT 名がグローバル保存される→下のガードが自己修復。

# グローバル model 汚染ガード（pre=起動前に正常値を退避＋前回クラッシュ分を復元 / post=終了後に汚染検知→復元）
# 汚染判定: gpt-* または難読クローク名（-dd- 含み）。素の Claude モデル名（claude-fable-5 等）は正当値として触らない
_claudex_model_guard() {
  python3 - "$1" "$HOME/.claude/settings.json" "$HOME/.claude/.claudex-global-model.bak" <<'PY'
import json, os, sys, tempfile
mode, settings, bak = sys.argv[1], sys.argv[2], sys.argv[3]
ABSENT = "__ABSENT__"
def polluted(v):
    return isinstance(v, str) and (v.startswith("gpt-") or "-dd-" in v)
try:
    data = json.load(open(settings))
except Exception:
    sys.exit(0)  # settings が読めない時は何もしない（壊さない）
cur = data.get("model", ABSENT)
def write_settings():
    fd, tmp = tempfile.mkstemp(prefix=".claudex-guard.", dir=os.path.dirname(settings))
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2); f.write("\n")
    os.replace(tmp, settings)
def restore():
    saved = open(bak).read().strip()
    if saved == ABSENT:
        data.pop("model", None)
    else:
        data["model"] = saved
    write_settings()
    label = "(キー削除)" if saved == ABSENT else repr(saved)
    print(f"claudex: グローバル model を復元しました（{cur!r} → {label}）", file=sys.stderr)
if not polluted(cur):
    if mode == "pre":  # 正常値を退避（post では触らない: 正常なら何もすることがない）
        fd, tmp = tempfile.mkstemp(prefix=".claudex-bak.", dir=os.path.dirname(bak))
        with os.fdopen(fd, "w") as f:
            f.write(cur if isinstance(cur, str) else ABSENT)
        os.replace(tmp, bak)
elif os.path.exists(bak):
    restore()  # pre=前回クラッシュ等の残留汚染 / post=今セッションの直打ち保存 を復元
else:
    print("claudex: ⚠ グローバル model が GPT 名のまま退避が見つかりません。"
          "~/.claude/settings.json の model を手動で確認してください", file=sys.stderr)
PY
}

claudex() {
  local model="gpt-5.6-sol"
  case "$1" in
    sol|terra|luna) model="gpt-5.6-$1"; shift ;;
    5.5|5.4) model="gpt-$1"; shift ;;
    gpt-*) model="$1"; shift ;;   # "gpt-5.6-sol(xhigh)" 等の effort サフィックス込みも透過
  esac
  _claudex_model_guard pre
  # スロット割当（CLIProxyAPI 公式推奨の v2 系 env）: ピッカーやサブエージェントの
  # opus/sonnet/haiku/fable 指定がそのまま GPT 系へ解決される
  ANTHROPIC_BASE_URL=http://127.0.0.1:8317 \
  ANTHROPIC_AUTH_TOKEN=$(security find-generic-password -s cliproxyapi-local-key -w) \
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
