# locale_sheet

[![pub package](https://img.shields.io/pub/v/locale_sheet.svg)](https://pub.dev)
[![license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)

locale_sheet は、Excel スプレッドシートを単一の真実の情報源（Single Source of Truth）として扱い、ローカライズ文字列を複数形式（現状: ARB）に変換する軽量な Dart CLI / ライブラリです。

## Quick Start

1. 依存を追加（`pubspec.yaml`）:

```yaml
dependencies:
  locale_sheet: ^1.0.0
```

2. パッケージを取得して実行（CLI）:

```bash
dart pub get
dart run bin/locale_sheet.dart export --input path/to/translations.xlsx --format arb --out ./lib/l10n
```

3. プログラム的に使う（最短）:

```dart
import 'package:args/command_runner.dart';
import 'package:locale_sheet/locale_sheet.dart';

void main() async {
  final runner = CommandRunner<int>('locale_sheet', 'programmatic runner')
    ..addCommand(ExportCommand());

  await runner.run(['export', '--input', 'path/to/file.xlsx', '--out', './lib/l10n']);
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

開発向けのテストは `dart test` で実行します。カバレッジの生成には付属スクリプトを利用してください:

```bash
bash scripts/coverage.sh
```

## Contributing

- コードをフォーマット: `dart format .`
- テストを追加/修正: `dart test`
- カバレッジの更新: `bash scripts/coverage.sh`

## License

MIT
