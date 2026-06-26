#!/usr/bin/env zsh
# Claude Code statusLine スクリプト
# stdin から JSON を受け取り、1行でステータスを表示する
#   [バー] 使用率% | 5h:.. | Cx:.. | モデル名 | Gitブランチ | カレントディレクトリ

input=$(cat)

# 通常色＝青。古い（resets_at が過去）スナップショットは無装飾に落とす方針。
# コンテキストバーは独自の緑/黄/赤色のため対象外。
blue=$'\033[34m'
ncolor=$'\033[0m'

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
  # 有効（resets_at 未来 or 不明）なら青、古い（過去）なら無装飾
  if [[ -z "$reset_at" ]] || (( reset_at > $(date +%s) )); then
    rl5_part="${blue}${rl5_part}${ncolor}"
  fi
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
      # 新しいスナップショット（resets_at が未来＝有効）なら青で強調。
      # 古い（窓リセット済み）なら通常色（無装飾）で控えめに。
      # 注意: Cx 値は Codex 最終実行時点のもの。新しい Codex 実行までは更新されない
      if [[ -n "$cx_reset" ]]; then
        cx_now=$(date +%s)
        if (( cx_reset > cx_now )); then
          cx_part="${blue}${cx_part}${ncolor}"
        fi
      fi
    fi
  fi
fi

# --- 稼働中エージェント（このセッションの subagent 作業＝in_progress タスク） ---
# ソース: ~/.claude/tasks/<session_id>/*.json の status=="in_progress"
#   session_id は statusLine 入力にそのまま入るのでディレクトリを直接引ける。
# 「稼働中か」の判定: in_progress に切り替わった時刻（task json の mtime）からの
#   経過時間を併記する。statusLine が描画されている＝現セッションは生存中なので、
#   経過が異常に長い in_progress は stall/取りこぼし疑い（黄色で警告）。
#   ⚠ in-process エージェントは専用 PID/heartbeat を持たないため、サブエージェントが
#   crash して lead が completed にし損ねると in_progress のまま残りうる（経過時間で気付ける）。
agent_part=""
sid=$(echo "$input" | jq -r '.session_id // empty')
if [[ -n "$sid" && -d "${HOME}/.claude/tasks/${sid}" ]]; then
  tdir="${HOME}/.claude/tasks/${sid}"
  ip_count=0
  show_subj=""
  show_mtime=0
  # (N)=null_glob: マッチ無しでも空。各 in_progress を走査し、最長稼働中（mtime 最小＝
  #   一番前に in_progress 化＝stall を最も疑うべき）1件を代表表示する。
  for tf in "${tdir}"/*.json(N.); do
    st=$(jq -r '.status // empty' "$tf" 2>/dev/null)
    [[ "$st" == "in_progress" ]] || continue
    ip_count=$(( ip_count + 1 ))
    mt=$(stat -f %m "$tf" 2>/dev/null)
    [[ -z "$mt" ]] && mt=0
    # 代表＝最も古く in_progress 化した（mtime 最小）タスク＝最長稼働
    if (( show_mtime == 0 || mt < show_mtime )); then
      show_mtime=$mt
      show_subj=$(jq -r '.subject // .description // ""' "$tf" 2>/dev/null)
    fi
  done
  if (( ip_count > 0 )); then
    # 代表タスク名を 14 文字に短縮（改行は除去）
    show_subj="${show_subj//$'\n'/ }"
    [[ ${#show_subj} -gt 14 ]] && show_subj="${show_subj[1,14]}…"
    # 経過時間（in_progress 化からの分）
    el_part=""
    if (( show_mtime > 0 )); then
      el=$(( ($(date +%s) - show_mtime) / 60 ))
      (( el < 0 )) && el=0
      if   (( el >= 60 )); then el_part="$(( el / 60 ))h$(( el % 60 ))m"
      else                      el_part="${el}m"
      fi
    fi
    # 色: 通常はシアン、20 分以上 in_progress なら stall 疑いで黄色
    if (( show_mtime > 0 )) && (( ($(date +%s) - show_mtime) >= 1200 )); then
      acolor=$'\033[33m'
    else
      acolor=$'\033[36m'
    fi
    areset=$'\033[0m'
    if [[ -n "$show_subj" ]]; then
      agent_part="${acolor}⚙${ip_count} ${show_subj}${el_part:+ (${el_part})}${areset}"
    else
      agent_part="${acolor}⚙${ip_count}${el_part:+ (${el_part})}${areset}"
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
  # 未コミット変更があれば * を付与（コミット忘れ防止）
  if [[ -n "$branch" ]] && [[ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]]; then
    branch="${branch}*"
  fi
fi

# --- 出力を組み立て ---
parts=("$ctx_part")
[[ -n "$rl5_part" ]] && parts+=("$rl5_part")
[[ -n "$cx_part" ]] && parts+=("$cx_part")
[[ -n "$agent_part" ]] && parts+=("$agent_part")
parts+=("${blue}${model}${ncolor}")
[[ -n "$branch" ]] && parts+=("${blue}${branch}${ncolor}")
parts+=("${blue}${cwd_short}${ncolor}")

output=""
for part in "${parts[@]}"; do
  if [[ -z "$output" ]]; then
    output="$part"
  else
    output="$output | $part"
  fi
done

echo "$output"
