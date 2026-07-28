# CLAUDE.md

このファイルは Claude Code がプロジェクト規約を読み込むための入口です。
規約の本体は [AGENTS.md](./AGENTS.md) にあります。内容をここへ複製せず、AGENTS.md 側を更新してください。

@AGENTS.md

## クイックリファレンス

コマンドはすべてリポジトリルートで実行します。Dart / Flutter SDK は FVM 経由（`.fvmrc` で固定）です。

| 目的 | Mac/Linux | Windows |
| --- | --- | --- |
| テスト | `fvm dart test` | `fvm dart test` |
| 静的解析 | `fvm dart analyze` | `fvm dart analyze` |
| フォーマット | `make format` | `make.ps1 format` |
| カバレッジ | `make coverage` | `make.ps1 coverage` |
| 一括検証（PR 前に推奨） | `make verify` | `make.ps1 verify` |

`verify` は clean → format → `dart fix --dry-run` チェック → analyze → test → カバレッジの順に実行します。
CI（[.github/workflows/verify.yml](.github/workflows/verify.yml)）も同じ `scripts/verify.sh` を実行するため、ローカルで通れば CI もほぼ通ります。

## 作業時の注意

- `main` に直接コミットしない。必ずブランチを切って PR を出す。
- コミットメッセージは Conventional Commits（`feat:` / `fix:` / `docs:` / `chore:` / `ci:` など）。
- ソースを変更したらテスト・静的解析・カバレッジを実行し、結果を PR 本文に記載する（AGENTS.md「コード変更ポリシー」）。
- テストは `lib/src/` と 1:1 で配置し、AAA パターン（`// Arrange` / `// Act` / `// Assert`）と日本語の意図コメント（`///`）を付ける。
- 外部仕様を変えたら `README.md` と `README_ja.md` の両方を更新し、`CHANGELOG.md` に追記する（版と日付は publish 時に確定するため、PR 時点では `vx.x.x 20xx-xx-xx` をプレースホルダとして使う）。
- `CHANGELOG.md` は pub.dev に公開される利用者向けの文書。`AGENTS.md` / `CLAUDE.md` / `doc/` の更新や CI・設定の変更は書かない（AGENTS.md「ドキュメントと履歴管理」を参照）。
