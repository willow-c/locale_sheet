# locale_sheet (開発者向け)

このドキュメントは開発者・メンテナ向けの情報を集約した `locale_sheet` の開発用 README です。

## 概要

`locale_sheet` はスプレッドシート（Excel）を単一の真実の情報源として扱い、ローカライズ文字列を複数の出力形式（初期実装: ARB）に変換する Dart CLI / ライブラリです。

## 開発に必要なツール

- fvm（Dartバージョン管理）
- lcov（カバレッジHTMLレポート生成用）

Homebrew でのインストール例（macOS）:

```bash
brew tap leoafarias/fvm
brew install fvm
brew install lcov
```

## プロジェクト構成

- `bin/` — CLI エントリポイント（`bin/locale_sheet.dart`）
- `lib/` — コア実装（公開 API は `lib/locale_sheet.dart`）
  - `lib/src/core/` — ドメインモデル・パーサ・ロジック
  - `lib/src/cli/` — CLI アダプタ・ロガー
  - `lib/src/exporters/` — 出力エクスポーター群（例: `arb_exporter.dart`）
- `test/` — ユニット / 統合テスト
- `scripts/` — カバレッジ・クリーン用スクリプト
- `AGENTS.md` — エージェントによる自動化・運用履歴

## 主な開発方針

- すべてのソースファイルに 1:1 のテストファイルを用意し、テストカバレッジを高く保つ。
- CLI ロジックは `CommandRunner` と `ExportCommand` を使い、`ExportCommand` は `logger` / `parser` / `exporters` を注入可能にしてユニットテストを容易にする。
- ドキュメントやエージェントによる自動化は `AGENTS.md` に記録する。

## Excel フォーマット仕様（開発メモ）

- 1行目はヘッダ行。1列目は `key`。2列目以降はロケールコード（`en`, `ja` 等）。
- 2行目以降が翻訳エントリ。空セルは未定義として扱う。

例:
|key|en|ja|
|:--|:--|:--|
|hello|Hello|こんにちは|
|bye|Goodbye|さようなら|

## テスト実行とカバレッジ

- 単体テスト: `fvm dart test` または `dart test`（fvm 使用推奨）
- カバレッジ: `bash scripts/coverage.sh` または `make coverage`（HTML レポート: `coverage/html/index.html`）

## CI / 開発フロー提案

- PR 作成時に `dart test` と `dart format --set-exit-if-changed .` を実行する CI ワークフローを追加する。
- カバレッジが著しく低下した場合はレビューを必須にする。

## ExportCommand の注入方法（開発者向けサンプル）

`ExportCommand` は次の依存をコンストラクタで差し替え可能です:

- `logger`: ログ出力をカスタマイズするための `Logger` 実装
- `parser`: `ExcelParser` の差し替え（テスト用のフェイク実装など）
- `exporters`: `LocalizationExporter` マップ（例: `{ 'arb': ArbExporter() }`）

テスト用の簡単な例:

```dart
final cmd = ExportCommand(
  logger: SimpleLogger(),
  parser: FakeExcelParser(),
  exporters: {'arb': FakeExporter()},
);

final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);
await runner.run(['export', '--input', 'dummy.xlsx']);
```

## ドキュメントの管理

- ユーザー向けの `README.md`（パッケージトップ）は短く、pub.dev 向けの説明に集中する。
- 詳細な開発手順、設計ノート、拡張ポイントは `docs/developer/README.md` に集約する。

## 次の作業候補

- `docs/architecture.md` を作成して、パーサ・モデル・エクスポーターの詳細を図付きで記述する。
- `CONTRIBUTING.md` を追加して開発フロー（ブランチ戦略・PR ガイドライン）を明示する。
