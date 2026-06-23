#!/usr/bin/env zsh
# Claude Code statusLine スクリプト
# stdin から JSON を受け取り、1行でステータスを表示する
#   [バー] 使用率% | 5h:.. | Cx:.. | モデル名 | Gitブランチ | カレントディレクトリ

input=$(cat)

# epoch 秒 → "→HH:MM(残XhYm)" を返す（過去/失敗時は空文字）
fmt_reset_suffix() {
  local epoch="$1" hm now remain rh rm out=""
  [[ -z "$epoch" ]] && { echo ""; return; }
  hm=$(date -r "$epoch" +%H:%M 2>/dev/null || date -d "@$epoch" +%H:%M 2>/dev/null)
  [[ -z "$hm" ]] && { echo ""; return; }
  out="→${hm}"
  now=$(date +%s)
  remain=$(( epoch - now ))
  if (( remain > 0 )); then
    rh=$(( remain / 3600 ))
    rm=$(( (remain % 3600) / 60 ))
    if (( rh > 0 )); then out="${out}(残${rh}h${rm}m)"; else out="${out}(残${rm}m)"; fi
  fi
  echo "$out"
}

# --- コンテキスト使用率（初回メッセージ前は null の場合あり） ---
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [[ -n "$used" ]]; then
  used_int=$(LC_ALL=C printf '%.0f' "$used")
  (( used_int < 0 )) && used_int=0
  (( used_int > 100 )) && used_int=100

  # 10 文字バー（▓=使用 / ░=残り）
  bar_len=10
  filled=$(( (used_int * bar_len + 50) / 100 ))
  (( filled > bar_len )) && filled=bar_len
  empty=$(( bar_len - filled ))

  bar=""
  for ((i=0; i<filled; i++)); do bar+="▓"; done
  for ((i=0; i<empty;  i++)); do bar+="░"; done

  # 色分け（緑<50 / 黄50-79 / 赤>=80）
  if   (( used_int >= 80 )); then color=$'\033[31m'
  elif (( used_int >= 50 )); then color=$'\033[33m'
  else                            color=$'\033[32m'
  fi
  reset=$'\033[0m'
  ctx_part="${color}[${bar}] ${used_int}%${reset}"
else
  ctx_part="[░░░░░░░░░░] --"
fi

# --- Claude 5時間レート制限（サブスクのみ・初回API後に出現） ---
rl5=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl5_part=""
if [[ -n "$rl5" ]]; then
  rl5_int=$(LC_ALL=C printf '%.0f' "$rl5")
  reset_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
  rl5_part="5h:${rl5_int}%$(fmt_reset_suffix "$reset_at")"
fi

# --- Codex 使用量（最新セッションログのレート制限スナップショット・5時間枠=primary） ---
# 注意: Codex を最後に実行した時点の値（リアルタイムではない）
cx_part=""
# (N)=null_glob: マッチ無しでもエラーにせず空配列 / (.)=通常ファイル / (om)=更新時刻降順
cx_files=( ${HOME}/.codex/sessions/*/*/*/rollout-*.jsonl(N.om) )
cx_session="${cx_files[1]}"
if [[ -n "$cx_session" ]]; then
  # 末尾だけ読む（大きいログ対策）。最後の rate_limits 行を採用
  cx_line=$(tail -c 300000 "$cx_session" 2>/dev/null | grep '"rate_limits"' | tail -1)
  if [[ -n "$cx_line" ]]; then
    # rate_limits はネスト位置が変わりうるので再帰検索で最後の primary を採用
    cx_pct=$(echo "$cx_line" | jq -r 'first([.. | .rate_limits? | objects][-1].primary.used_percent // empty) // empty' 2>/dev/null)
    cx_reset=$(echo "$cx_line" | jq -r 'first([.. | .rate_limits? | objects][-1].primary.resets_at // empty) // empty' 2>/dev/null)
    if [[ -n "$cx_pct" ]]; then
      cx_int=$(LC_ALL=C printf '%.0f' "$cx_pct")
      cx_part="Cx:${cx_int}%$(fmt_reset_suffix "$cx_reset")"
    fi
  fi
fi

# --- モデル名 ---
model=$(echo "$input" | jq -r '.model.display_name // empty')
[[ -z "$model" ]] && model="--"

# --- カレントディレクトリ（~ 短縮） ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
if [[ -n "$cwd" ]]; then
  home="$HOME"
  cwd_short="${cwd/#$home/~}"
else
  cwd_short="--"
fi

# --- Git ブランチ（カレントディレクトリで取得。失敗時は非表示） ---
branch=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir &>/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

# --- 出力を組み立て ---
parts=("$ctx_part")
[[ -n "$rl5_part" ]] && parts+=("$rl5_part")
[[ -n "$cx_part" ]] && parts+=("$cx_part")
parts+=("$model")
[[ -n "$branch" ]] && parts+=("$branch")
parts+=("$cwd_short")

output=""
for part in "${parts[@]}"; do
  if [[ -z "$output" ]]; then
    output="$part"
  else
    output="$output | $part"
  fi
done

echo "$output"
