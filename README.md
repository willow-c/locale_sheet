# locale_sheet

`locale_sheet` はスプレッドシート（Excel）を単一の真実の情報源として扱い、ローカライズ文字列を複数形式に変換するための Dart CLI パッケージです。

## 開発に必要なツール

- fvm（Dartバージョン管理、推奨）
- lcov（カバレッジHTMLレポート生成用）

### Dart & fvm

#### Homebrew (Mac)
```bash
brew install dart fvm
```

#### fvm（Dartバージョン管理）
詳しくは https://fvm.app/ を参照してください。

### lcov（カバレッジHTMLレポート用）

#### Mac (Homebrew)
```bash
brew install lcov
```

## 主な機能

- Excel をパースして内部モデルに変換する
- 複数の出力エクスポーター（初期実装: ARB）へ変換する
- ライブラリとしての注入可能な API を提供（テストや自動化に便利）


## ディレクトリ構成（2026年1月時点）

- `bin/` — CLIエントリポイント（`bin/locale_sheet.dart`）
- `lib/` — コア実装（UI非依存）
  - `lib/locale_sheet.dart` — 公開API
  - `lib/src/core/` — ドメインモデル・パーサ・ロジック（例: localization_entry.dart, parser.dart, model.dart, localization_sheet.dart など）
  - `lib/src/cli/` — CLIアダプタ・ロガー（cli.dart, logger.dart）
  - `lib/src/exporters/` — 各種エクスポーター（arb_exporter.dart等）
- `test/` — ユニット/統合テスト（lib/src/の構成に合わせて core/ cli/ exporters/ などサブディレクトリ化）
- `scripts/` — カバレッジ・クリーン用スクリプト（Bash/PowerShell両対応）
- `AGENTS.md` — エージェント/自動化運用方針・履歴

> ※ `lib/src/exporter.dart` など旧ファイルは不要です。exporters/配下に統合済みのため削除してください。

## Excel フォーマット仕様

- 1行目はヘッダ行です。
  - 1列目ヘッダは必須で `key` としてください。
  - 2列目以降はロケールコード（例: `en`, `ja`, `es`）を指定します。
- 2行目以降は翻訳行です。
  - 1列目: 翻訳キー（例: `hello`）
  - 2列目以降: 各ロケールの翻訳文字列。空欄は未定義として扱われます。

例:

```
key,en,ja
hello,Hello,こんにちは
bye,Goodbye,さようなら
```

※ 現在は単純な文字列のみサポートしています。プレースホルダや複数形、説明などは今後の拡張候補です。

## CLI（コマンドライン）

依存を取得して実行します（`fvm` を利用することを推奨します）:

```bash
fvm dart pub get
```

エクスポート例:

```bash
fvm dart run bin/locale_sheet.dart export --input path/to/translations.xlsx --format arb --out ./lib/l10n
```

- `--input`/`-i`: 入力 XLSX ファイルのパス
- `--format`: 出力形式（現状は `arb` のみ）
- `--out`/`-o`: 出力ディレクトリ（存在しない場合は作成されます）

CLI のヘルプは日本語化されており、`export --help` で詳細が確認できます。

出力例: `./lib/l10n/app_en.arb`, `./lib/l10n/app_ja.arb`

## サンプル実行
```bash
fvm dart run bin/locale_sheet.dart export --input example/sample.xlsx --format arb --out ./lib/l10n
```

## プログラム的 API

ライブラリの公開関数を使って、コード内から直接変換できます。

```dart
import 'package:locale_sheet/locale_sheet.dart';

await convertExcelToArb(inputPath: 'path/to/translations.xlsx', outDir: 'lib/l10n');
```

テストしやすさのため、バイト列を受け取る `convertExcelBytesToArb` と、エクスポーターを注入できる設計になっています。


## テストとカバレッジ・自動化方針

- すべてのソースファイルに1:1でテストファイルを用意し、カバレッジレポート（lcov.info）で不足箇所を可視化・改善します。
- カバレッジ・クリーン・ビルド等のスクリプトは scripts/ 配下にBash/PowerShell両対応で用意。
- エージェント/自動化によるコード・ドキュメント生成・リファクタ履歴は AGENTS.md に記録。
- クロスプラットフォーム（Windows/macOS/Linux）で動作確認済み。

## クリーンアップ（生成物・テスト結果の削除）

開発中に生成されるカバレッジ・テスト生成物や .arb ファイル、l10n ディレクトリなどを一括削除できます。

### Mac/Linux (Bash)
```bash
bash scripts/clean.sh
```

### Windows (PowerShell)
```powershell
pwsh scripts/clean.ps1
```

主に削除されるもの:
- coverage/ ディレクトリ
- .dart_tool/ ディレクトリ
- l10n/ ディレクトリ（lib/test配下など）
- *.arb ファイル
- .DS_Store など

### テスト実行

```bash
fvm dart test
```

### カバレッジ（lcov）をワンコマンドで生成

#### Mac/Linux (Bash)

```bash
bash scripts/coverage.sh
```

#### Windows (PowerShell)

```powershell
pwsh scripts/coverage.ps1
```

#### Makefile（Mac/Linux/WSL）

```bash
make coverage
```

#### Dartコマンド（手動実行・クロスプラットフォーム）

```bash
fvm dart test --coverage=coverage
fvm dart pub global run coverage:format_coverage --packages=.dart_tool/package_config.json --in=coverage --out=coverage/lcov.info --lcov
```

> どちらも `coverage/lcov.info` を生成します。

> `scripts/coverage.sh`（Bash）と `scripts/coverage.ps1`（PowerShell）は `fvm` があれば自動で利用し、なければ `dart` を使います。
> どちらも `coverage/lcov.info` を生成し、`genhtml` コマンドがあれば `coverage/html/index.html` も自動生成します。

#### HTMLカバレッジレポートの閲覧

`genhtml` コマンドがインストールされていれば、上記スクリプト実行後に `coverage/html/index.html` をブラウザで開くことで、視覚的なカバレッジレポートを確認できます。

CI等では `coverage/lcov.info` を利用してください。


## 変更履歴（最近の主要な変更・運用）

- ディレクトリ構成を core/ cli/ exporters/ サブディレクトリ化し、責務ごとに整理
- すべてのソースファイルに1:1でテストファイルを用意し、カバレッジ100%を目指す運用に
- AGENTS.mdを新設し、エージェント/自動化による履歴・運用方針を明記
- CLIをCommandRunnerベースに移行し、ExportCommandをlib/src/cli/cli.dartに移動（テスト容易性向上）
- convertExcelToArbのファイル読み取りを同期→非同期に変更
- Loggerインターフェース導入、CLIメッセージ日本語化
- ARB出力でキーをアルファベット順にソートし、出力差分を安定化

## 拡張ポイント

- `lib/src/exporters/` に新しいエクスポーター（例: `resx_exporter.dart`, `json_exporter.dart`）を追加できます。
- モデルとパーサを拡張すれば、プレースホルダや複数形、説明の取り込みが可能です。

## ライセンス

MIT
