
# CLIProxyAPI 経由の Claude Code（GPT系バックエンド・DRレーン）。キーは Keychain 参照（平文非保持）
# 禁止: cliproxyapi の -claude-login（Anthropic OAuth取込）は絶対に使わない（規約違反・BAN実績あり。
#       この構成の安全性は「GPT側OAuthのみプロキシに持たせ、Claude側認証は素のまま」の分離が根拠）
# 使い方: claudex（既定=sol）/ claudex terra / claudex luna / claudex 5.5 / claudex gpt-5.4 …残り引数はclaudeへ透過
claudex() {
  local model="gpt-5.6-sol"
  case "$1" in
    sol|terra|luna) model="gpt-5.6-$1"; shift ;;
    5.5|5.4) model="gpt-$1"; shift ;;
    gpt-*) model="$1"; shift ;;
  esac
  ANTHROPIC_BASE_URL=http://127.0.0.1:8317 \
  ANTHROPIC_AUTH_TOKEN=$(security find-generic-password -s cliproxyapi-local-key -w) \
  claude --model "$model" "$@"
}
