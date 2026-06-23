#!/bin/bash
# Cmd+Option+クリックでコードファイルを指定エディタ（色付き）で開くための既定ハンドラ設定。
#
# 背景: cmux で app.openSupportedFilesInCmux=true のとき、ターミナルの file:// クリックは
#   Cmd+クリック        → cmux 内蔵プレビュー（プレーン）
#   Cmd+Option+クリック → OS既定ハンドラ（LaunchServices）へ素通し
# となる。この「OS既定」を好みのエディタにすることで Cmd+Option+クリック→色付き表示を実現する。
#
# 使い方:
#   ./set-editor-default.sh "Visual Studio Code"   # アプリ名
#   ./set-editor-default.sh "Cursor"
#   ./set-editor-default.sh "Zed"
#   ./set-editor-default.sh "Sublime Text"
#   ./set-editor-default.sh com.microsoft.VSCode   # バンドルID直接指定も可
#
# 要: 指定エディタがインストール済み。LaunchServices の既定を変更する点に留意（任意実行）。
set -e

APP="${1:-}"
if [ -z "$APP" ]; then
  echo "使い方: $0 \"<エディタのアプリ名 または バンドルID>\""
  echo "  例: $0 \"Visual Studio Code\" / \"Cursor\" / \"Zed\" / \"Sublime Text\""
  exit 1
fi

if ! command -v duti >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then brew install duti; else
    echo "⚠ duti が必要です。brew install duti を実行してください"; exit 1
  fi
fi

# アプリ名 → バンドルID を解決（既にバンドルID形式ならそのまま使う）
case "$APP" in
  *.*.*) BID="$APP" ;;
  *) BID=$(osascript -e "id of app \"$APP\"" 2>/dev/null || true) ;;
esac
if [ -z "$BID" ]; then
  echo "⚠ '$APP' のバンドルIDを解決できません。アプリ名が正確か（または .app がインストール済みか）確認してください"
  exit 1
fi

# 開発でよく触る拡張子。必要に応じて増減する
EXTS="php twig js mjs cjs ts jsx tsx json jsonc yaml yml md css scss sass less html htm xml py rb go rs sh bash zsh sql vue svelte env conf ini toml"
for e in $EXTS; do
  duti -s "$BID" ".$e" all 2>/dev/null || true
done
echo "✅ コード拡張子の既定アプリを '$APP' ($BID) に設定（Cmd+Option+クリックで開く）"

# VS Code の場合のみ twig 色付け拡張を導入（PHP は標準対応）
if [ "$BID" = "com.microsoft.VSCode" ] && command -v code >/dev/null 2>&1; then
  code --install-extension mblode.twig-language-2 2>/dev/null || true
  echo "  twig 拡張(mblode.twig-language-2)を導入"
fi
