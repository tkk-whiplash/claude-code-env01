---
name: plugin-zip
description: ECプラグインやツールの配布ZIPを作成する。「配布ZIP作って」「リリースZIP」「ZIP化して」等の依頼で使用。事前チェック（テスト・バージョン）→白ラベル検査→正しいZIP構造→検証まで一括実行する
---

# 配布ZIP作成

ECプラットフォーム向け自作プラグインの配布ZIPを、毎回同じ品質で作るための手順。

## 1. 対象とバージョンの特定

- プラグインディレクトリ（`app/Plugin/<Name>`）を特定。ユーザー指定がなければ確認する
- `composer.json` の `version` が今回のリリース内容に対して更新済みか確認。未更新なら更新を提案

## 2. 事前チェック

- 直近のテストが green か確認（このセッションで未実行なら `docker compose exec ec-cube ./vendor/bin/phpunit app/Plugin/<Name>/Tests` を単体実行）
- 未コミット変更が混入しないか `git status` で確認（意図しない作業途中ファイルが入るのを防ぐ）

## 3. 白ラベル検査（必須）

ユーザー可視テキストに製品名ワード（「EC-CUBE」「ＥＣキューブ」等）が含まれていないか検査する（配布・白ラベル化ルール）:

```bash
grep -rn -i -e "EC-CUBE" -e "eccube" --include="*.twig" --include="*.md" app/Plugin/<Name>/ | grep -v -e "Eccube\\\\" -e "use Eccube" -e "eccube_" -e "@EccubeVersion"
```

- 名前空間（`Eccube\`）・テンプレート関数・設定キーは除外してよい（コードとして必要）
- **画面表示文言・README・コメントでのヒットは修正してから続行**

## 4. ZIP作成（構造ルール厳守）

**ZIPルート直下に `composer.json` を置くこと**（`<Name>/composer.json` のように1階層挟む形はインストール失敗するためNG）:

```bash
cd app/Plugin/<Name> && zip -r <Name>-<version>-$(date +%Y%m%d).zip . \
  -x "*/CLAUDE.md" -x "CLAUDE.md" -x "*/.DS_Store" -x ".DS_Store" -x "*.git*"
```

## 5. 検証

```bash
unzip -l <zip> | head -20
```

- ルート直下に `composer.json` があること
- `CLAUDE.md` / `.DS_Store` / `.git` が含まれていないこと
- ZIPサイズが異常でないこと（巨大な場合は除外漏れを疑う）

## 6. 出力先

- ユーザー指定があればそこへ。なければプロジェクトの配布用フォルダ（例: `配布用ZIP/`）の有無を確認して配置
- 作成したZIPのフルパス・サイズ・含有ファイル数を報告する

## 注意

- Pythonツール等のWindows配布キットはプロジェクト固有の手順（過去の配布キット構成）を優先し、本スキルは構造検証の考え方のみ流用する
- 本番デプロイ自体はユーザーが実施する（こちらからは行わない）
