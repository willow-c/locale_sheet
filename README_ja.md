# locale_sheet

[![pub package](https://img.shields.io/pub/v/locale_sheet.svg)](https://pub.dev/packages/locale_sheet)
[![license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)

[README (English)](./README.md) | [README (日本語)](./README_ja.md)

locale_sheet は、Excel スプレッドシートを単一の真実の情報源（Single Source of Truth）として扱い、ローカライズ文字列を複数形式（現状: ARB）に変換する軽量な Dart CLI / ライブラリです。

## Quick Start

1. 依存を追加（`pubspec.yaml`）:

```yaml
dev_dependencies:
  locale_sheet: ^0.1.1
```

1. パッケージを取得して実行（CLI）:

```bash
dart pub get
dart run locale_sheet export --input ./example/sample.xlsx --format arb --out ./lib/l10n --default-locale en
```

補足:

- `--default-locale` オプション（短縮 `-d`）は、デフォルト言語とするロケールを指定します。
- `--default-locale` を省略した場合、シートに `en` が存在すれば `en` をデフォルトとして使用し、なければ最初のロケール列をデフォルトにします。

1. プログラム的に使う（最短）:

```dart
import 'package:args/command_runner.dart';
import 'package:locale_sheet/locale_sheet.dart';

void main() async {
  final runner = CommandRunner<int>('locale_sheet', 'programmatic runner')
    ..addCommand(ExportCommand());

  // Programmatic 実行（default-locale 指定例）:
  await runner.run([
    'export',
    '--input',
    'path/to/file.xlsx',
    '--out',
    './lib/l10n',
    '--default-locale',
    'en',
  ]);
}
```

## Features

- Excel (.xlsx) をパースして内部モデルに変換
- ARB 形式への出力（キーはアルファベット順にソート）
- CLI とライブラリの両方で利用可能

## Usage

- CLI オプション:
  - `--input` / `-i`: 入力 XLSX ファイルのパス（必須）
  - `--format`: 出力形式（`arb`）
  - `--out` / `-o`: 出力ディレクトリ（デフォルト: `.`）
  - `--default-locale` / `-d`: デフォルト言語とするロケールを指定します。指定したロケールがシートに存在しない場合は終了コード `64` でエラー終了します。未指定時はシートに `en` があれば `en` を使い、なければ最初のロケール列を使用します。

- 主な公開 API:
  - `convertExcelToArb({required String inputPath, required String outDir, ExcelParser? parser, LocalizationExporter? exporter})`
  - `convertExcelBytesToArb(Uint8List bytes, LocalizationExporter exporter, String outDir, {ExcelParser? parser})`
  - `ExportCommand` — `CommandRunner` に登録して CLI をプログラム内から実行できます。

## Examples

サンプルは `example/` ディレクトリを参照してください（XLSX の最小フォーマット例と出力先のサンプルを含みます）。

## Exit Codes & Error Handling

- `64` — 引数エラー / UsageException
- `1` — 実行時エラー（ファイル I/O やパースエラーなど）

## Testing & Coverage

開発向けのテストは下記で実行します:

```bash
dart test
```

カバレッジの生成には付属スクリプトを利用してください:

```bash
bash scripts/coverage.sh
```

## Contributing

- コードをフォーマット: `dart format .`
- テストを追加/修正: `dart test`
- カバレッジの更新: `bash scripts/coverage.sh`

## License

MIT
