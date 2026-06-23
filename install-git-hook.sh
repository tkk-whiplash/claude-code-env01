#!/bin/bash
# gitleaks pre-commit フックを現在のリポジトリに設置する
# 使い方: 対象リポジトリのルートで実行（または引数にリポジトリパスを渡す）
set -e
REPO="${1:-.}"
if [ ! -d "$REPO/.git" ]; then
  echo "エラー: $REPO は git リポジトリではありません"; exit 1
fi
if [ -f "$REPO/.git/hooks/pre-commit" ]; then
  echo "⚠ 既存の pre-commit フックがあります。中身を確認してから手動で統合してください: $REPO/.git/hooks/pre-commit"
  exit 1
fi
cat > "$REPO/.git/hooks/pre-commit" << 'EOF'
#!/bin/sh
exec "$HOME/.config/git/hooks/gitleaks-pre-commit.sh" "$@"
EOF
chmod +x "$REPO/.git/hooks/pre-commit"
echo "✅ gitleaks pre-commit を設置: $REPO"
