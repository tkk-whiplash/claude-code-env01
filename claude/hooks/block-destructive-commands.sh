#!/usr/bin/env bash
# PreToolUse(Bash) フック
# カタストロフィックなコマンドのみ機械的に deny / 流出経路は ask（確認強制）。
# 通常の破壊操作（プロジェクト内 rm -rf * 等）は通常の許可フローに委ねる＝過剰ブロックを避ける。
# 判定: 終了コード0 + JSON(permissionDecision)。該当なしは exit 0（素通り）。
# 注意: これは「完全防御」ではなく事故防止層。変数経由(A=/; rm -rf "$A")やセパレータ跨ぎ等は
#       検知しきれない。確実な禁止は権限(deny)や運用と多層で担保すること。

input=$(cat)

# jq 不在/不全時は fail-closed（ask に倒す）。安全判定不能のまま素通り(allow)させない
if ! command -v jq >/dev/null 2>&1; then
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"jq未導入のため危険コマンド判定不可。内容を確認して承認してください（brew install jq 推奨）"}}'
  exit 0
fi

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$cmd" ]] && exit 0

# 連続空白を単一化して評価しやすく
norm=$(printf '%s' "$cmd" | tr '\n\t' '  ' | tr -s ' ')
# クォート(' ")を除去した走査用文字列。rm -rf "$HOME" / dd of="/dev/disk2" 等のクォート迂回を防ぐ
scan=$(printf '%s' "$norm" | tr -d '\042\047')

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
ask() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
}

# --- rm が再帰+強制かどうか ---
rm_is_recursive_force() {
  printf '%s' "$1" | grep -qE '\brm\b' || return 1
  printf '%s' "$1" | grep -qiE '\brm\b[^|;&]*(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|--recursive[^|;&]*--force|--force[^|;&]*--recursive|-r[a-z]*[[:space:]]+-f|-f[a-z]*[[:space:]]+-r)'
}

# --- 致命的ターゲット（絶対システムパス / ホーム / ルート） ---
rm_hits_critical_target() {
  printf '%s' "$1" | grep -qiE '\brm\b[^|;&]*[[:space:]](/|/\*|~|~/|\$HOME|\$\{HOME\}|/bin|/boot|/dev|/etc|/lib|/lib64|/opt|/proc|/root|/sbin|/sys|/usr|/var|/System|/Applications|/Library|/Users)([[:space:]/]|\*|$)'
}

# 1) 致命的 rm -rf（/ ~ $HOME システムパス）→ deny
if rm_is_recursive_force "$scan" && rm_hits_critical_target "$scan"; then
  deny "致命的な rm -rf（/, ~, \$HOME, システムパス）を遮断しました。意図的なら手動で実行してください。"
fi

# 2) fork bomb
if printf '%s' "$scan" | grep -qE ':\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:'; then
  deny "fork bomb を遮断しました。"
fi

# 3) ファイルシステム/ブロックデバイス破壊
if printf '%s' "$scan" | grep -qiE '\bmkfs(\.[a-z0-9]+)?\b|\bdd\b[^|;&]*of=/dev/|>[[:space:]]*/dev/(sd|disk|nvme|rdisk|hd)|\bof=/dev/r?disk'; then
  deny "ブロックデバイス/ファイルシステム破壊コマンド（mkfs/dd of=/dev/ 等）を遮断しました。"
fi

# 4) システムディレクトリへの再帰的な権限/所有者破壊（プロジェクト配下の絶対パスは対象外）
SYSDIRS='(/|/bin|/boot|/dev|/etc|/lib|/lib64|/opt|/proc|/root|/sbin|/sys|/usr|/var|/System|/Applications|/Library|/Users)'
if printf '%s' "$scan" | grep -qiE "\bchmod\b[^|;&]*-R[^|;&]*[[:space:]]777[[:space:]]+${SYSDIRS}([[:space:]/]|$)" \
 || printf '%s' "$scan" | grep -qiE "\bchown\b[^|;&]*-R[^|;&]*[[:space:]]${SYSDIRS}([[:space:]/]|$)"; then
  deny "システムディレクトリへの再帰的な権限/所有者変更を遮断しました。"
fi

# 5) find / -delete / -exec rm
if printf '%s' "$scan" | grep -qiE '\bfind\b[[:space:]]+/[[:space:]][^|;&]*(-delete|-exec[[:space:]]+rm)'; then
  deny "ルートからの find -delete/-exec rm を遮断しました。"
fi

# 6) git config のシステム設定変更（CLAUDE.md 禁止事項）
if printf '%s' "$scan" | grep -qiE '\bgit[[:space:]]+config\b[^|;&]*--system'; then
  deny "git config --system（システム設定変更）は禁止です。"
fi

# 7) ネットワーク→シェル直実行（curl|sh 等）→ ask（確認強制）
if printf '%s' "$scan" | grep -qiE '\b(curl|wget|fetch)\b[^|;&]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash|zsh|python[0-9.]*|ruby|node|perl)\b'; then
  ask "リモート取得物をシェルに直接パイプしています。内容を確認のうえ承認してください。"
fi

# 8) sudo（管理者権限）→ ask（確認強制・遮断はしない）。コマンド位置のみ判定＝文字列中の "sudo" は誤検知しない
if printf '%s' "$scan" | grep -qE '(^|[|;&]|\$\()[[:space:]]*sudo([[:space:]]|$)'; then
  ask "sudo（管理者権限）でのシステム変更です。直前にAIが目的・影響・戻し方を説明しているか確認してから承認してください（説明が無ければ問い返しを）。"
fi

exit 0
