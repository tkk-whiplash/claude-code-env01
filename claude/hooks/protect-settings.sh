#!/usr/bin/env bash
# PreToolUse(Edit|Write|MultiEdit) フック
# settings.json / CLAUDE.md / .claude 配下への「権限無効化・認可境界破壊」キー注入を deny する。
# CVE-2025-59536 / CVE-2026-21852 クラス（設定経由の権限破壊・APIキー窃取）への自衛。
# 既存キーの削除（deny ルール除去等）は検知対象外＝diff レビューで補完すること（浅い自衛層）。

input=$(cat)

# jq 不在/不全時は fail-closed（ask に倒す）。判定不能のまま素通り(allow)させない
if ! command -v jq >/dev/null 2>&1; then
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"jq未導入のため設定改ざん判定不可。内容を確認して承認してください（brew install jq 推奨）"}}'
  exit 0
fi

fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -z "$fp" ]] && exit 0

# 対象ファイルだけを検査（それ以外は素通り）
case "$fp" in
  *settings.json|*settings.local.json|*managed-settings.json|*.claude/*|*CLAUDE.md|*CLAUDE.local.md) ;;
  *) exit 0 ;;
esac

# 追加/書込される新コンテンツを抽出（Edit:new_string / Write:content / MultiEdit:edits[].new_string）
content=$(printf '%s' "$input" | jq -r '
  [ .tool_input.new_string?,
    .tool_input.content?,
    ( .tool_input.edits // [] | .[]?.new_string )
  ] | map(select(. != null)) | join("\n")' 2>/dev/null)
[[ -z "$content" ]] && exit 0

# 危険キーは「代入形（"key": 値）」に限定して照合する。
# 散文でキー名に言及するだけ（README/CLAUDE.md の説明文等）は誤 deny しない（false positive 回避）。
DANGER='"?skipAutoPermissionPrompt"?[[:space:]]*:[[:space:]]*true'
DANGER+='|"?enableAllProjectMcpServers"?[[:space:]]*:[[:space:]]*true'
DANGER+='|"?disableAllHooks"?[[:space:]]*:[[:space:]]*true'
DANGER+='|"?allowManagedHooksOnly"?[[:space:]]*:[[:space:]]*false'
DANGER+='|"?defaultMode"?[[:space:]]*:[[:space:]]*"bypassPermissions"'
DANGER+='|"?(ANTHROPIC_BASE_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY)"?[[:space:]]*:'
DANGER+='|"?apiKeyHelper"?[[:space:]]*:'

if printf '%s' "$content" | grep -qiE "$DANGER"; then
  jq -n --arg f "$fp" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("設定/指示ファイル(" + $f + ")への権限無効化・認可境界破壊キーの注入を遮断しました。意図的な変更なら、このフックを一時的に外して手動で行ってください。")}}'
  exit 0
fi

# JSON Unicode エスケープ(\uXXXX)による難読化はキー照合を迂回しうる。
# 設定/指示ファイルに \u00XX を含む変更は安全に判定できないため ask（確認強制）に倒す。
if printf '%s' "$content" | grep -qiE '\\u00[0-9a-f]{2}'; then
  jq -n --arg f "$fp" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:("設定/指示ファイル(" + $f + ")に Unicodeエスケープ(\\uXXXX)が含まれます。難読化された権限変更でないか確認して承認してください。")}}'
  exit 0
fi

exit 0
