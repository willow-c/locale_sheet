# locale_sheet (開発者向け)

このドキュメントは開発者・メンテナ向けの情報を集約した `locale_sheet` の開発用 README です。

## 概要

`locale_sheet` はスプレッドシート（Excel）を単一の真実の情報源として扱い、ローカライズ文字列を複数の出力形式（初期実装: ARB）に変換する Dart CLI / ライブラリです。

## 開発に必要なツール

- fvm（Dart/Flutter バージョン管理。バージョンは `.fvmrc` で固定）
- lcov（カバレッジHTMLレポート生成用。`genhtml` を使う）
- `coverage` パッケージ（`scripts/coverage.sh` が `pub global run coverage:format_coverage` を使うため必須）

Homebrew でのインストール例（macOS）:

```bash
brew tap leoafarias/fvm
brew install fvm
brew install lcov
```

`coverage` パッケージはグローバルに有効化します（未実施だと `make coverage` が失敗します）:

```bash
fvm dart pub global activate coverage
```

## プロジェクト構成

- `bin/` — CLI エントリポイント（`bin/locale_sheet.dart`）
- `lib/` — コア実装（公開 API は `lib/locale_sheet.dart`）
  - `lib/src/core/` — ドメインモデル・パーサ・ロジック
  - `lib/src/cli/` — CLI アダプタ・ロガー
  - `lib/src/exporters/` — 出力エクスポーター群（例: `arb_exporter.dart`）
- `test/` — ユニット / 統合テスト
- `scripts/` — 検証・カバレッジ・フォーマット・クリーン用スクリプト（`verify.sh` / `coverage.sh` / `format.sh` / `clean.sh` と対応する `.ps1`）
- `AGENTS.md` — AIエージェント・自動化ツールの利用方針と運用手順

## 主な開発方針

- すべてのソースファイルに 1:1 のテストファイルを用意し、テストカバレッジを高く保つ。
- CLI ロジックは `CommandRunner` と `ExportCommand` を使い、`ExportCommand` は `logger` / `parser` / `exporters` を注入可能にしてユニットテストを容易にする。
- ドキュメントやエージェントによる自動化は `AGENTS.md` に記録する。

## Excel フォーマット仕様（開発メモ）

- 1行目はヘッダ行。1列目は `key` でなければならず、そうでなければ `FormatException` になる。
- 2列目以降のうち、**ロケールタグとして妥当なヘッダを持つ列だけ**がロケール列として扱われる（判定は `lib/src/core/model_helpers.dart` の `isValidLocaleTag`）。`備考` のようなロケールでない列は無視されるため、途中に混ざっていても後続の列がずれることはない。
- `--description-header` で指定したヘッダの列は説明列として扱われ、ロケール列からは除外される。ヘッダがロケールタグとして妥当な場合は、指定ミスとみなしてエラーになる。
- 2行目以降が翻訳エントリ。空セルは未定義として扱う。`key` が空の行と空行はスキップされる。
- 同じ `key` が複数行にある場合も解析は成功する。CLI は該当キーごとに `WARNING` を出し、エクスポート時はロケールごとに後の行が優先される。

例（`example/sample.xlsx` の `Sheet1` を簡略化したもの）:

|key|en|ja|description|備考|
|:--|:--|:--|:--|:--|
|hello|Hello|こんにちは|the text 'Hello'|こんにちはの文言|
|bye|Goodbye|さようなら|the text 'Goodbye'|さようならの文言|

`--description-header description` を指定した場合、ロケール列は `en` と `ja` のみになり、`description` は説明として、`備考` は無視される。

## テスト実行とカバレッジ

- 単体テスト: `fvm dart test` または `dart test`（fvm 使用推奨）
- カバレッジ: `bash scripts/coverage.sh` または `make coverage`（HTML レポート: `coverage/html/index.html`）

## CI / 開発フロー

- `main` / `develop` への push と PR で [.github/workflows/verify.yml](../../.github/workflows/verify.yml) が実行される。
- ワークフローは FVM で Flutter SDK を用意したうえで `scripts/verify.sh` を実行する。内訳は clean → format → `dart fix --dry-run` チェック → `dart analyze` → `dart test` → カバレッジ収集。
- カバレッジは Codecov にアップロードされ、`coverage/` は artifact として 30 日保持される。
- ローカルでも同じ流れを `make verify`（Windows は `make.ps1 verify`）で再現できる。PR を出す前に実行しておくと CI での差し戻しを防げる。

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
- 詳細な開発手順、設計ノート、拡張ポイントは `doc/developer/README.md` に集約する。

## 次の作業候補

- `doc/architecture.md` を作成して、パーサ・モデル・エクスポーターの詳細を図付きで記述する。
- `CONTRIBUTING.md` を追加して開発フロー（ブランチ戦略・PR ガイドライン）を明示する。
