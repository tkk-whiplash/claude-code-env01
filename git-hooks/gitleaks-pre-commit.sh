#!/bin/bash
# gitleaks pre-commit 共通スクリプト: ステージ済み変更の秘密情報スキャン
# 一時スキップ: SKIP_GITLEAKS=1 git commit ...
# 恒久的な誤検知除外: リポジトリ直下の .gitleaksignore に fingerprint を追記
[ "$SKIP_GITLEAKS" = "1" ] && exit 0
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "[pre-commit] gitleaks 未インストールのためスキャンをスキップ（brew install gitleaks）"
  exit 0
fi
# v8.19以降は `gitleaks git`、それ以前は `gitleaks protect`
if gitleaks git --help >/dev/null 2>&1; then
  gitleaks git --pre-commit --staged --redact -v
else
  gitleaks protect --staged --redact -v
fi
status=$?
if [ $status -ne 0 ]; then
  echo ""
  echo "[pre-commit] 秘密情報らしき内容を検出したためコミットを中止しました。"
  echo "  誤検知なら: SKIP_GITLEAKS=1 git commit ...（一時スキップ）"
  echo "  恒久除外: .gitleaksignore に上記 Fingerprint を追記"
  exit 1
fi
exit 0
