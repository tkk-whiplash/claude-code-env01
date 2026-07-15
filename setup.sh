#!/bin/bash
# Claude Code 環境再現キット セットアップ（macOS想定・コンポーネント選択式）
#
# 使い方:
#   ./setup.sh                          # 対話形式で1つずつ選択
#   ./setup.sh --yes                    # 全部入り（質問なし）
#   ./setup.sh --minimal                # 初心者最小構成（security/statusline/cmux のみ）
#   ./setup.sh --yes --skip=codex,gemini  # codex/gemini連携を除いて全部入り
#
# コンポーネントキー:
#   superpowers  計画/TDDワークフローskill群プラグイン
#   lsp          PHP/Python LSPプラグイン
#   mdmgmt       CLAUDE.md管理プラグイン
#   codex        Codex連携（プラグイン+MCP+デュアルレビューagent+協働ループ規約）
#   gemini       Gemini連携（MCP+大型資料委譲規約）
#   context7     ライブラリ最新ドキュメントMCP
#   playwright   ブラウザ操作MCP（--isolated＝複数セッション同時実行可）
#   security     セキュリティフック（破壊的コマンド遮断 + 設定改ざん防止 PreToolUse）
#   statusline   ステータスライン（コンテキスト/レート制限/Codex使用量/モデル/ブランチ表示）
#   cmux         cmux クリック設定（Cmd+クリック→内蔵プレビュー。VS Code連携は任意スクリプト）
#   staleness    棚卸しリマインダーフック（90日で警告）
#   gitleaks     秘密情報コミット防止（brew+共通pre-commitフック）
#   zip          配布ZIP作成スキル（ECプラグイン向け）
#   fetchjs      JSレンダリングページ取得スキル
#   agent-teams  Agent Teams（複数エージェント並列・env+teammateMode=auto+workflow警告抑制／分割ペインは任意・トークン約7倍）
#   notifications 入力待ち/完了のデスクトップ・プッシュ通知
#   remote-control 起動時にリモート操作を有効化（web/モバイルから操作）
#   model-tiers  モデル対応表（能力クラス→実モデル・レビュー複雑度サブ表）
#   cliproxy     GPTバックエンドレーン（CLIProxyAPI＋claudex関数・ChatGPTサブスクでGPT系モデル起動）
#   managed      組織強制設定（配布端末/非エンジニア向け・root所有managed-settings＝deny+bypass封鎖。--yesでは入らない）
set -e
cd "$(dirname "$0")"
TS=$(date +%Y%m%d-%H%M%S)

YES_ALL=0
SKIP=","
for a in "$@"; do
  case "$a" in
    --yes) YES_ALL=1 ;;
    --minimal) YES_ALL=1; SKIP=",superpowers,lsp,mdmgmt,codex,gemini,context7,playwright,staleness,gitleaks,zip,fetchjs,agent-teams,notifications,remote-control,model-tiers,cliproxy,managed," ;;
    --skip=*) SKIP=",${a#--skip=}," ;;
    -h|--help) sed -n '2,31p' "$0"; exit 0 ;;
  esac
done

ask() { # $1=キー $2=説明 → "y"/"n" を返す
  case "$SKIP" in *",$1,"*) echo n; return ;; esac
  if [ "$YES_ALL" = 1 ]; then echo y; return; fi
  printf "  [%s] %s を導入? [Y/n] " "$1" "$2" > /dev/tty
  read -r ans < /dev/tty
  case "$ans" in [nN]*) echo n ;; *) echo y ;; esac
}

echo "=== コンポーネント選択 ==="
C_SUPERPOWERS=$(ask superpowers "superpowers（計画/TDDワークフロー）")
C_LSP=$(ask lsp "LSPプラグイン（PHP/Python）")
C_MDMGMT=$(ask mdmgmt "claude-md-management（CLAUDE.md管理）")
C_CODEX=$(ask codex "Codex連携（デュアルレビュー・協働ループ）")
C_GEMINI=$(ask gemini "Gemini連携（大型資料の読解委譲）")
C_CONTEXT7=$(ask context7 "Context7 MCP（ライブラリ最新ドキュメント）")
C_PLAYWRIGHT=$(ask playwright "Playwright MCP（--isolated＝複数セッション同時実行可）")
C_SECURITY=$(ask security "セキュリティフック（破壊的コマンド遮断＋設定改ざん防止）")
C_STATUSLINE=$(ask statusline "ステータスライン（コンテキスト/レート制限/Codex使用量表示）")
C_CMUX=$(ask cmux "cmux クリック設定（Cmd+クリックで内蔵プレビュー）")
C_STALENESS=$(ask staleness "棚卸しリマインダー（90日で警告フック）")
C_GITLEAKS=$(ask gitleaks "gitleaks（秘密情報コミット防止）")
C_ZIP=$(ask zip "plugin-zipスキル（配布ZIP定型化）")
C_FETCHJS=$(ask fetchjs "fetch-js-pageスキル（JSページ取得）")
echo "  --- エージェントハーネス設定（好みで。未選択でも基本機能は動く） ---"
C_AGENTTEAMS=$(ask agent-teams "Agent Teams＝複数AIを並列実行して協調（teammateMode=auto: 分割ペインはtmux/iTerm2があれば、無ければ画面内パネル。トークン約7倍）")
C_NOTIFICATIONS=$(ask notifications "通知＝入力待ち/作業完了をデスクトップ・プッシュで知らせる")
C_REMOTECONTROL=$(ask remote-control "リモート操作＝起動時にweb/モバイルからの操作を有効化")
C_MODELTIERS=$(ask model-tiers "モデル対応表（能力クラス→実モデル・レビュー複雑度サブ表を ~/.claude/model-tiers.md に配置）")
C_CLIPROXY=$(ask cliproxy "GPTバックエンドレーン（CLIProxyAPI＋claudex＝ChatGPTサブスクでGPT系モデルをClaude Codeから起動・DR用）")
if [ "$YES_ALL" = 1 ]; then
  C_MANAGED=n   # 制限を加える系は --yes で勝手に入れない（対話実行でのみ提案）
else
  C_MANAGED=$(ask managed "組織強制設定（配布端末/非エンジニア向け。認証情報denyとbypassPermissions封鎖を root 所有で固定＝ユーザー側で変更不能。自分の開発機には通常不要）")
fi

echo ""
echo "=== 前提ツールの確認（書き込み前にチェック） ==="
# 致命的: python3 が無いと settings.json 生成不可 → 何も書かずに中断（中途半端な状態を作らない）
if ! command -v python3 >/dev/null 2>&1; then
  echo "  ✗ python3 が見つかりません（settings.json 生成に必須）"
  echo "    導入: xcode-select --install  → 完了後にもう一度 ./setup.sh"
  echo "  ※ 設定ファイルは一切変更していません（安全に中断しました）"
  exit 1
fi
echo "  ✓ python3"
# 警告のみ（後で自動導入を試みる/手動導入を促す）
if { [ "$C_SECURITY" = y ] || [ "$C_STATUSLINE" = y ]; } && ! command -v jq >/dev/null 2>&1; then
  echo "  ⚠ jq 未検出（security/statusline に必要）。後で brew install を試みます"
fi
if { [ "$C_PLAYWRIGHT" = y ] || [ "$C_CONTEXT7" = y ] || [ "$C_FETCHJS" = y ]; } && ! command -v npx >/dev/null 2>&1; then
  echo "  ⚠ node/npx 未検出（playwright/context7/fetchjs に必要）。Node.js を導入してください"
fi
command -v git >/dev/null 2>&1 || echo "  ⚠ git 未検出（clone/コミット系で必要）"

echo ""
echo "=== 1/5 既存設定のバックアップ ==="
mkdir -p ~/.claude
for f in CLAUDE.md settings.json; do
  if [ -f ~/.claude/$f ]; then
    cp ~/.claude/$f ~/.claude/$f.bak-$TS
    echo "  退避: ~/.claude/$f → $f.bak-$TS"
  fi
done

echo "=== 2/5 CLAUDE.md / settings.json 生成・配置 ==="
# CLAUDE.md: 非選択コンポーネントのセクションをマーカーで除去
TMP_CM=$(mktemp)
cp claude/CLAUDE.md "$TMP_CM"
strip_section() { # $1=マーカー名
  local t=$(mktemp)
  sed "/<!-- BEGIN:$1 -->/,/<!-- END:$1 -->/d" "$TMP_CM" > "$t" && mv "$t" "$TMP_CM"
}
[ "$C_GEMINI" = n ] && strip_section gemini
[ "$C_CODEX" = n ] && strip_section codex
[ "$C_PLAYWRIGHT" = n ] && strip_section playwright
[ "$C_MODELTIERS" = n ] && strip_section model-tiers
# 残ったマーカー行は除去
T2=$(mktemp); grep -v '^<!-- \(BEGIN\|END\):' "$TMP_CM" > "$T2" && mv "$T2" "$TMP_CM"
# 既存 CLAUDE.md は上書きしない（壊さない）。新版は .new-$TS に出して手動取り込みを促す
if [ -f ~/.claude/CLAUDE.md ]; then
  cp "$TMP_CM" ~/.claude/CLAUDE.md.new-$TS
  echo "  ⚠ 既存 ~/.claude/CLAUDE.md は保持。新版を CLAUDE.md.new-$TS に出力 → 差分を確認して手で取り込んでください: diff ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.new-$TS"
else
  cp "$TMP_CM" ~/.claude/CLAUDE.md
  echo "  CLAUDE.md を新規配置（<> プレースホルダは要編集）"
fi

# settings.json: 選択に応じて動的生成
COMPS=""
[ "$C_SUPERPOWERS" = y ] && COMPS="$COMPS,superpowers"
[ "$C_LSP" = y ] && COMPS="$COMPS,lsp"
[ "$C_MDMGMT" = y ] && COMPS="$COMPS,mdmgmt"
[ "$C_CODEX" = y ] && COMPS="$COMPS,codex"
[ "$C_SECURITY" = y ] && COMPS="$COMPS,security"
[ "$C_STATUSLINE" = y ] && COMPS="$COMPS,statusline"
[ "$C_STALENESS" = y ] && COMPS="$COMPS,staleness"
[ "$C_AGENTTEAMS" = y ] && COMPS="$COMPS,agent-teams"
[ "$C_NOTIFICATIONS" = y ] && COMPS="$COMPS,notifications"
[ "$C_REMOTECONTROL" = y ] && COMPS="$COMPS,remote-control"
python3 - "$COMPS" "$HOME" << 'PYEOF'
import json, sys, os
comps = set(filter(None, sys.argv[1].strip(',').split(',')))
home = sys.argv[2]
base = json.load(open('claude/settings.json'))
ep = base.get('enabledPlugins', {})
mk = base.get('extraKnownMarketplaces', {})
def drop(plugin, market=None):
    ep.pop(plugin, None)
    if market: mk.pop(market, None)
if 'superpowers' not in comps: drop('superpowers@superpowers-marketplace', 'superpowers-marketplace')
if 'codex' not in comps: drop('codex@openai-codex', 'openai-codex')
if 'lsp' not in comps:
    drop('php-lsp@claude-plugins-official'); drop('pyright-lsp@claude-plugins-official')
if 'mdmgmt' not in comps: drop('claude-md-management@claude-plugins-official')
# hooks は粒度別に取捨（staleness=SessionStart / security=PreToolUse）
hooks = base.get('hooks', {})
if 'staleness' not in comps: hooks.pop('SessionStart', None)
if 'security' not in comps: hooks.pop('PreToolUse', None)
if hooks: base['hooks'] = hooks
else: base.pop('hooks', None)
# statusLine は statusline コンポーネント選択時のみ
if 'statusline' not in comps: base.pop('statusLine', None)
# エージェントハーネス設定（コンポーネント選択時のみ）
if 'agent-teams' not in comps:
    base.get('env', {}).pop('CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS', None)
    base.pop('teammateMode', None); base.pop('skipWorkflowUsageWarning', None)
if not base.get('env'): base.pop('env', None)
if 'notifications' not in comps:
    base.pop('inputNeededNotifEnabled', None); base.pop('agentPushNotifEnabled', None)
if 'remote-control' not in comps:
    base.pop('remoteControlAtStartup', None)
# $HOME を実パスに展開
base = json.loads(json.dumps(base).replace('$HOME', home))

target = home + '/.claude/settings.json'
if os.path.exists(target):
    # 既存設定を壊さず「追加分だけ」マージする（置換しない）
    try:
        cur = json.load(open(target))
    except Exception:
        cur = {}
    perm = cur.setdefault('permissions', {})
    deny = perm.setdefault('deny', [])
    for d in base.get('permissions', {}).get('deny', []):
        if d not in deny: deny.append(d)          # deny は union
    if 'defaultMode' not in perm and 'defaultMode' in base.get('permissions', {}):
        perm['defaultMode'] = base['permissions']['defaultMode']
    bh = base.get('hooks', {})
    if bh:                                          # hooks は同一コマンドが無いものだけ追加
        def _norm(c):                               # $HOME/~ を実パスに正規化して比較（リテラルと絶対パスの重複を防ぐ）
            return (c or '').replace('$HOME', home).replace('~', home)
        ch = cur.setdefault('hooks', {})
        for event, groups in bh.items():
            cg = ch.setdefault(event, [])
            have = {_norm(h.get('command')) for grp in cg for h in grp.get('hooks', [])}
            for grp in groups:
                newh = [h for h in grp.get('hooks', []) if _norm(h.get('command')) not in have]
                if newh: cg.append(dict(grp, hooks=newh))
    if 'statusLine' in base and 'statusLine' not in cur:
        cur['statusLine'] = base['statusLine']     # 既存の statusLine は尊重（上書きしない）
    for key in ('enabledPlugins', 'extraKnownMarketplaces', 'env'):
        if base.get(key):
            dst = cur.setdefault(key, {})
            for k, v in base[key].items():
                if k not in dst: dst[k] = v          # 既存キーは保持・無いものだけ追加
    for k in ('teammateMode','skipWorkflowUsageWarning','inputNeededNotifEnabled','agentPushNotifEnabled','remoteControlAtStartup'):
        if k in base and k not in cur: cur[k] = base[k]   # 既存スカラー設定は尊重・無いものだけ追加
    result, mode = cur, 'マージ（既存を保持）'
else:
    result, mode = base, '新規作成'

tmp = target + '.tmp'                               # アトミック書き込み
open(tmp, 'w').write(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
os.replace(tmp, target)
print('  settings.json ' + mode + ': ' + (', '.join(sorted(comps)) if comps else 'コア設定のみ'))
PYEOF

echo "=== 3/5 agents / skills / hooks 配置 ==="
mkdir -p ~/.claude/agents ~/.claude/skills ~/.claude/hooks
if [ "$C_CODEX" = y ]; then
  cp claude/agents/code-reviewer.md ~/.claude/agents/ && echo "  agent: code-reviewer（デュアルレビュー）"
else
  echo "  agent: code-reviewer はスキップ（Codex前提のため）"
fi
if [ "$C_MODELTIERS" = y ]; then
  if [ -f ~/.claude/model-tiers.md ]; then
    cp ~/.claude/model-tiers.md ~/.claude/model-tiers.md.bak-$TS
    echo "  退避: model-tiers.md → model-tiers.md.bak-$TS"
  fi
  cp claude/model-tiers.md ~/.claude/model-tiers.md
  echo "  model-tiers.md: 能力クラス→モデル対応表＋レビュー複雑度サブ表（Codex/Claude両レッグ）"
fi
[ "$C_ZIP" = y ] && cp -R claude/skills/plugin-zip ~/.claude/skills/ && echo "  skill: plugin-zip"
if [ "$C_FETCHJS" = y ]; then
  cp -R claude/skills/fetch-js-page ~/.claude/skills/
  echo "  skill: fetch-js-page"
  if command -v npm >/dev/null 2>&1; then
    echo "    Playwright+Chromium を導入中（時間がかかる場合あり）…"
    ( cd ~/.claude/skills/fetch-js-page && npm i playwright >/dev/null 2>&1 && npx playwright install chromium >/dev/null 2>&1 ) \
      && echo "    ✅ Playwright+Chromium 導入済" \
      || echo "    ⚠ 自動導入失敗。手動: cd ~/.claude/skills/fetch-js-page && npm i playwright && npx playwright install chromium"
  else
    echo "    ⚠ npm 未検出。Node.js導入後: cd ~/.claude/skills/fetch-js-page && npm i playwright && npx playwright install chromium"
  fi
fi
if [ "$C_STALENESS" = y ]; then
  cp claude/hooks/harness-staleness-check.sh ~/.claude/hooks/
  chmod +x ~/.claude/hooks/harness-staleness-check.sh
  date +%F > ~/.claude/harness-audit-date
  echo "  hook: 棚卸しリマインダー（基準日=今日）"
fi
if [ "$C_SECURITY" = y ]; then
  cp claude/hooks/block-destructive-commands.sh claude/hooks/protect-settings.sh ~/.claude/hooks/
  chmod +x ~/.claude/hooks/block-destructive-commands.sh ~/.claude/hooks/protect-settings.sh
  echo "  hook: 破壊的コマンド遮断（PreToolUse:Bash）＋設定改ざん防止（PreToolUse:Edit/Write）"
fi
if [ "$C_STATUSLINE" = y ]; then
  cp claude/statusline-command.sh ~/.claude/
  chmod +x ~/.claude/statusline-command.sh
  echo "  statusLine: コンテキスト/レート制限/Codex使用量/モデル/ブランチ表示（要 jq）"
fi
if [ "$C_CMUX" = y ]; then
  # cmux.json は cmux 専用。Ghostty等の素の端末では読まれないのでスキップ
  if command -v cmux >/dev/null 2>&1 || [ -d "/Applications/cmux.app" ]; then
    mkdir -p ~/.config/cmux
    if [ -f ~/.config/cmux/cmux.json ]; then
      cp ~/.config/cmux/cmux.json ~/.config/cmux/cmux.json.bak-$TS
      echo "  退避: ~/.config/cmux/cmux.json → cmux.json.bak-$TS"
    fi
    cp claude/cmux/cmux.json ~/.config/cmux/cmux.json
    command -v cmux >/dev/null 2>&1 && cmux reload-config 2>/dev/null || true
    echo "  cmux: Cmd+クリック→内蔵プレビュー設定"
  else
    echo "  cmux 未検出（Ghostty等の素の端末）→ cmux.json はスキップ（読まれないため）"
    echo "    ※ file:// URL のクリック起動は端末側が処理。下のエディタ既定設定はGhosttyのCmd+クリックにも有効"
  fi
  # Cmd+Option+クリック（cmux）/ Cmd+クリック（Ghostty）で開くエディタの既定設定。
  # duti はLaunchServices既定を変えるため端末非依存＝cmux/Ghostty両対応。VS Codeとは限らないため都度選択
  if [ "$YES_ALL" = 1 ]; then
    echo "    Cmd+Option+クリックのエディタ既定は後で: ./claude/cmux/set-editor-default.sh \"<エディタ名>\""
  else
    printf "    Cmd+Option+クリックで開くエディタ名 (例: Visual Studio Code / Cursor / Zed、空Enter=スキップ): " > /dev/tty
    read -r ED < /dev/tty
    if [ -n "$ED" ]; then
      bash claude/cmux/set-editor-default.sh "$ED" || echo "    ⚠ エディタ既定設定に失敗（後で手動実行可）"
    else
      echo "    エディタ既定設定はスキップ（後で ./claude/cmux/set-editor-default.sh \"<名前>\"）"
    fi
  fi
fi

echo "=== 4/5 CLIツール・gitフック ==="
if [ "$C_CLIPROXY" = y ]; then
  if command -v brew >/dev/null 2>&1; then
    brew list cliproxyapi >/dev/null 2>&1 || brew install cliproxyapi
    CONF="$(brew --prefix)/etc/cliproxyapi.conf"
    if [ -f "$CONF" ]; then
      # ローカルAPIキー: Keychain に無ければ生成（画面に出さない）
      security find-generic-password -s cliproxyapi-local-key -w >/dev/null 2>&1 \
        || security add-generic-password -a "$USER" -s cliproxyapi-local-key -w "$(openssl rand -hex 24)" -U
      CLIPROXY_KEY="$(security find-generic-password -s cliproxyapi-local-key -w)" CONF="$CONF" python3 - <<'PYEOF'
import os
p = os.environ['CONF']; key = os.environ['CLIPROXY_KEY']
s = open(p).read()
ph = 'api-keys:\n  - "your-api-key-1"\n  - "your-api-key-2"\n  - "your-api-key-3"'
if key in s:                                            # 冪等: Keychainキーが既に設定済み
    print('  cliproxyapi.conf は構成済み（変更なし）')
elif ph in s:                                           # 既定形（プレースホルダ完全一致）のみ書き換え=all-or-nothing
    s = s.replace(ph, 'api-keys:\n  - "%s"' % key, 1)
    if 'host: ""' in s:                                 # ローカル限定bind（外部からの到達を遮断）
        s = s.replace('host: ""', 'host: "127.0.0.1"', 1)
    if 'disable-control-panel: false' in s:             # 管理パネルの自動DLを無効化
        s = s.replace('disable-control-panel: false', 'disable-control-panel: true', 1)
    open(p, 'w').write(s)
    print('  cliproxyapi.conf を最小構成化（127.0.0.1 bind・ローカルキー・管理パネルDL無効）')
else:                                                   # 既定形でない=手を入れず警告（部分書込みしない）
    print('  ⚠ cliproxyapi.conf が既定形と異なるため変更しません。api-keys に Keychain の cliproxyapi-local-key の値を手動設定してください')
PYEOF
      chmod 600 "$CONF"
    else
      echo "  ⚠ $CONF が見つからない（brew install 失敗の可能性）"
    fi
    if ! grep -q "claudex()" ~/.zshrc 2>/dev/null; then
      cat claude/cliproxy/claudex.zsh >> ~/.zshrc
      echo "  claudex 関数を ~/.zshrc に追加（claudex / claudex terra / claudex luna / claudex 5.5）"
    else
      echo "  claudex 関数は導入済み（~/.zshrc 変更なし）"
    fi
  else
    echo "  ⚠ Homebrew未検出。cliproxy コンポーネントをスキップ"
  fi
fi
if [ "$C_MANAGED" = y ]; then
  MS_DIR="/Library/Application Support/ClaudeCode"
  MS="$MS_DIR/managed-settings.json"
  if [ -f "$MS" ]; then
    echo "  ⚠ $MS が既に存在します。上書きしません（差分確認: diff \"$MS\" claude/managed-settings.json）"
  else
    echo "  managed-settings を設置します（root所有・sudo パスワードを求められます）"
    if sudo mkdir -p "$MS_DIR" && sudo cp claude/managed-settings.json "$MS" \
       && sudo chown root:wheel "$MS" && sudo chmod 644 "$MS"; then
      echo "  設置完了: $MS（deny＋bypass封鎖のみ＝日常の不便ゼロ）"
      echo "    外すとき: sudo rm \"$MS\""
    else
      echo "  ⚠ 設置失敗（sudo 権限を確認してください）"
    fi
  fi
fi
if [ "$C_GITLEAKS" = y ]; then
  if command -v brew >/dev/null 2>&1; then
    brew list gitleaks >/dev/null 2>&1 || brew install gitleaks
  else
    echo "  ⚠ Homebrew未検出。gitleaks を手動インストールしてください"
  fi
  mkdir -p ~/.config/git/hooks
  cp git-hooks/gitleaks-pre-commit.sh ~/.config/git/hooks/
  chmod +x ~/.config/git/hooks/gitleaks-pre-commit.sh
  echo "  gitleaks共通フック配置済。各リポジトリで ./install-git-hook.sh を実行"
fi
# jq は security/statusline に必須なので選択時のみ導入を試みる（gh 等は無断導入しない）
if [ "$C_SECURITY" = y ] || [ "$C_STATUSLINE" = y ]; then
  if command -v jq >/dev/null 2>&1; then :
  elif command -v brew >/dev/null 2>&1; then brew install jq
  else echo "  ⚠ jq 未検出（security/statusline に必須）。手動導入: https://jqlang.github.io/jq/"
  fi
fi

echo "=== 5/5 MCPサーバー登録 ==="
[ "$YES_ALL" = 1 ] && echo "  （--yes: 選択した MCP の登録で外部 npx パッケージを取得・実行します）"
if command -v claude >/dev/null 2>&1; then
  if [ "$C_CONTEXT7" = y ]; then
    claude mcp add -s user context7 -- npx -y @upstash/context7-mcp 2>/dev/null || echo "  context7: 登録済みまたは失敗（claude mcp list で確認）"
  fi
  if [ "$C_CODEX" = y ]; then
    if command -v codex >/dev/null 2>&1; then
      claude mcp add -s user codex -- codex mcp-server 2>/dev/null || echo "  codex: 登録済みまたは失敗"
    else
      echo "  ⚠ Codex CLI未検出。使う場合: npm i -g @openai/codex → codex ログイン → claude mcp add -s user codex -- codex mcp-server"
    fi
  fi
  if [ "$C_GEMINI" = y ]; then
    claude mcp add -s user gemini-cli -- npx -y gemini-mcp-tool 2>/dev/null || echo "  gemini-cli: 登録済みまたは失敗（要: gemini CLI認証）"
  fi
  if [ "$C_PLAYWRIGHT" = y ]; then
    # --isolated: セッションごとに独立プロファイル＝複数同時実行が可能（永続プロファイルのロック回避）
    claude mcp add -s user playwright -- npx @playwright/mcp@latest --isolated 2>/dev/null || echo "  playwright: 登録済みまたは失敗（claude mcp list で確認）"
  fi
else
  echo "  ⚠ claude コマンド未検出。先に Claude Code をインストールしてください"
fi

echo ""
echo "✅ セットアップ完了。残りの手動ステップ:"
echo "  ・ claude を起動 → 初回にプラグインのインストール/信頼を承認"
[ "$C_CODEX" = y ] && echo "  ・ Codex CLI で認証（codex でログイン）"
[ "$C_GEMINI" = y ] && echo "  ・ Gemini CLI で認証"
if [ "$C_CLIPROXY" = y ]; then
  echo "  ・ GPTレーン認証: cliproxyapi -codex-login（ブラウザでChatGPT Plus/Proアカウント認証）"
  echo "  ・ GPTレーン常駐化: brew services start cliproxyapi → 新しいターミナルで claudex"
  echo "    ⚠ CLIProxyAPI の -claude-login は絶対に使わない（Anthropic規約違反・BAN実績あり）"
fi
echo "  ・ ~/.claude/CLAUDE.md の <> プレースホルダ（画像保存先等）を自分用に編集"
echo "  ・ 秘密情報は Keychain 登録: security add-generic-password -a \"\$USER\" -s <名前> -w <値> -U"
[ "$C_GITLEAKS" = y ] && echo "  ・ 主要リポジトリで ./install-git-hook.sh を実行（gitleaks pre-commit）"
[ "$C_CMUX" = y ] && echo "  ・ （任意/未設定なら）Cmd+Option+クリックで開くエディタ既定: ./claude/cmux/set-editor-default.sh \"<エディタ名>\""
