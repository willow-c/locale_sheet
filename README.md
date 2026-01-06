# locale_sheet

[![pub package](https://img.shields.io/pub/v/locale_sheet.svg)](https://pub.dev/packages/locale_sheet)
[![license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)

[README (English)](./README.md) | [README (日本語)](./README_ja.md)

`locale_sheet` is a lightweight Dart CLI and library that treats an Excel spreadsheet as a single source of truth and converts localization strings into multiple output formats (currently: ARB).

## Quick Start

1. Add the dependency to your `pubspec.yaml`:

```yaml
dev_dependencies:
  locale_sheet: ^0.0.1
```

2. Install dependencies and run the CLI:

```bash
dart pub get
dart run locale_sheet export --input ./example/sample.xlsx --format arb --out ./lib/l10n --default-locale en
```

Notes:
- The `--default-locale` option (short `-d`) specifies a fallback locale to use when a translation is missing.
- If `--default-locale` is omitted, the CLI will use `en` if present in the sheet; otherwise it uses the first locale column.

3. Programmatic usage (minimal):

```dart
import 'package:args/command_runner.dart';
import 'package:locale_sheet/locale_sheet.dart';

void main() async {
  final runner = CommandRunner<int>('locale_sheet', 'programmatic runner')
    ..addCommand(ExportCommand());

  // Programmatic invocation (with default-locale):
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

- Parses Excel (.xlsx) into an internal model
- Exports to ARB format (keys are sorted alphabetically)
- Available as both a CLI and a library

## Usage

- CLI options:
  - `--input` / `-i`: Path to the input XLSX file (required)
  - `--format`: Output format (e.g. `arb`)
  - `--out` / `-o`: Output directory (default: `.`)

- Main public API:
  - `convertExcelToArb({required String inputPath, required String outDir, ExcelParser? parser, LocalizationExporter? exporter})`
  - `convertExcelBytesToArb(Uint8List bytes, LocalizationExporter exporter, String outDir, {ExcelParser? parser})`
  - `ExportCommand` — can be registered with a `CommandRunner` to run the CLI programmatically.

## Examples

See the `example/` directory for sample XLSX files and example usage.

## Exit Codes & Error Handling

- `64` — argument error / UsageException
- `1` — runtime error (file I/O, parsing errors, etc.)

## Testing & Coverage

Run unit tests with:

```bash
dart test
```

Generate coverage using the bundled script:

```bash
bash scripts/coverage.sh
```

## Contributing

- Format code: `dart format .`
- Add/update tests: `dart test`
- Update coverage: `bash scripts/coverage.sh`

## License

MIT
