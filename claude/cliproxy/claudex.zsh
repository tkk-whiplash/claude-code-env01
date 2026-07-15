# CLIProxyAPI 経由の Claude Code（GPT系バックエンド・DRレーン）。キーは Keychain 参照（平文非保持）
# 禁止: cliproxyapi の -claude-login（Anthropic OAuth取込）は絶対に使わない（規約違反・BAN実績あり。
#       この構成の安全性は「GPT側OAuthのみプロキシに持たせ、Claude側認証は素のまま」の分離が根拠）
# 使い方: claudex（既定=sol）/ claudex terra / claudex luna / claudex 5.5 / claudex gpt-5.4 …残り引数はclaudeへ透過
# /model ピッカー: Claude プリセットを隠し GPT だけ表示（Default 1行は本体仕様で消せない=中身は sol に解決）。
#   仕組み=discovery キャッシュの実IDから availableModels を毎起動自動生成（自己修復）。初回はキャッシュ生成のみ→2回目から適用
claudex() {
  local model="gpt-5.6-sol"
  case "$1" in
    sol|terra|luna) model="gpt-5.6-$1"; shift ;;
    5.5|5.4) model="gpt-$1"; shift ;;
    gpt-*) model="$1"; shift ;;
  esac
  # /model ピッカーを GPT だけにする: discovery キャッシュの実ID（クローク難読名）から availableModels を
  # 自動生成（IDが将来変わっても追従＝自己修復）。Default 行は本体仕様で消せないため sol へ寄せる。
  # キャッシュが無い初回は allowlist を作らず全表示フォールバック（次回起動から効く）。
  local cache="$HOME/.claude/cache/gateway-models.json"
  local settings=""
  if [ -f "$cache" ]; then
    python3 - "$cache" "$HOME/.claude/claudex-settings.json" <<'PY' && settings="$HOME/.claude/claudex-settings.json"
import json, os, sys, tempfile
cache, out = sys.argv[1], sys.argv[2]
try:
    ids = [m["id"] for m in json.load(open(cache)).get("models", []) if m.get("id")]
except Exception:
    sys.exit(1)
if not ids:
    sys.exit(1)
# Default 行の解決先を GPT 5.6 Sol に（display_name で sol を探す。無ければ先頭）
sol = next((m["id"] for m in json.load(open(cache)).get("models", []) if m.get("display_name","").endswith("Sol")), ids[0])
data = {"availableModels": ids, "enforceAvailableModels": True, "model": sol}
fd, tmp = tempfile.mkstemp(prefix=".claudex-set.", dir=os.path.dirname(out))
with os.fdopen(fd, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2); f.write("\n")
os.replace(tmp, out)
PY
  fi
  ANTHROPIC_BASE_URL=http://127.0.0.1:8317 \
  ANTHROPIC_AUTH_TOKEN=$(security find-generic-password -s cliproxyapi-local-key -w) \
  CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 \
  claude --model "$model" ${settings:+--settings "$settings"} "$@"
}
