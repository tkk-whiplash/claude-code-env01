#!/bin/bash
# ハーネス棚卸しリマインダー（SessionStart hook）
# ~/.claude/harness-audit-date（YYYY-MM-DD）から90日以上経過したらセッション冒頭に警告を注入する。
# 期限内は無音。日付ファイルが不正・存在しない日付・未来日の場合は無音にせず警告を出す（サイレント故障防止）。
AUDIT_FILE="$HOME/.claude/harness-audit-date"
[ -f "$AUDIT_FILE" ] || exit 0
LAST=$(tr -d '[:space:]' < "$AUDIT_FILE")
if ! [[ "$LAST" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "⚠️ ハーネス棚卸しリマインダー: ~/.claude/harness-audit-date の内容が不正です('${LAST}')。YYYY-MM-DD 形式で修正してください。"
  exit 0
fi
LAST_EPOCH=$(date -j -f "%Y-%m-%d" "$LAST" +%s 2>/dev/null)
if [ -z "$LAST_EPOCH" ] || [ "$(date -j -f "%s" "$LAST_EPOCH" +%Y-%m-%d 2>/dev/null)" != "$LAST" ]; then
  echo "⚠️ ハーネス棚卸しリマインダー: ~/.claude/harness-audit-date が存在しない日付です('${LAST}')。修正してください。"
  exit 0
fi
NOW_EPOCH=$(date +%s)
DAYS=$(( (NOW_EPOCH - LAST_EPOCH) / 86400 ))
if [ "$DAYS" -lt 0 ]; then
  echo "⚠️ ハーネス棚卸しリマインダー: ~/.claude/harness-audit-date が未来日になっています('${LAST}')。修正してください。"
  exit 0
fi
if [ "$DAYS" -ge 90 ]; then
  echo "⚠️ ハーネス棚卸しリマインダー: 前回棚卸し(${LAST})から${DAYS}日経過(90日以上)。モデルエイリアス・プラグイン・MCP・permissionsの点検時期。見直しは Claude Code に『claude-code-env01 で環境を見直して』と頼む（または SETUP.md 参照）。完了後に ~/.claude/harness-audit-date を当日日付へ更新するとこの警告は消える。"
fi
exit 0
