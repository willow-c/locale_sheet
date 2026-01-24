# locale_sheet

[![pub package](https://img.shields.io/pub/v/locale_sheet.svg)](https://pub.dev/packages/locale_sheet)
[![license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)
[![CI](https://github.com/willow-c/locale_sheet/actions/workflows/verify.yml/badge.svg)](https://github.com/willow-c/locale_sheet/actions/workflows/verify.yml)

[README (English)](./README.md) | [README (日本語)](./README_ja.md)

`locale_sheet` is a lightweight Dart CLI and library that treats an Excel spreadsheet as a single source of truth and converts localization strings into multiple output formats (currently: ARB).

## Quick Start

1. Add the dependency to your `pubspec.yaml`:

    ```yaml
    dev_dependencies:
    locale_sheet: ^0.4.0
    ```

1. Install dependencies and run the CLI:

    ```bash
    dart pub get
    dart run locale_sheet export --input ./example/sample.xlsx --format arb --out ./lib/l10n --sheet-name Sheet1 --default-locale en --description-header description
    ```

    Notes:

    - The `--default-locale` option (short `-d`) specifies the locale to be used as the default language.
    - If `--default-locale` is omitted, the CLI will use `en` if present in the sheet; otherwise it uses the first locale column.

    Example: enable placeholder auto-detection and auto-add undefined placeholders:

    ```bash
    dart run locale_sheet export \
      --input ./example/sample.xlsx \
      --format arb \
      --out ./lib/l10n \
      --sheet-name Sheet1 \
      --default-locale en \
      --description-header description \
      --auto-detect-placeholders \
      --treat-undefined-placeholders=add \
      --placeholder-default-type=String
    ```

1. Programmatic usage (minimal):

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
          '--description-header',
          'description',
        ]);

      // Alternatively, call the library helper directly and pass the
      // optional `descriptionHeader` argument:
      // await convertExcelToArb(
      //   inputPath: 'path/to/file.xlsx',
      //   outDir: './lib/l10n',
      //   descriptionHeader: 'description',
      // );
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
  - `--default-locale` / `-d`: Specifies the locale to be used as the default language. If specified and the locale is not present in the sheet, the command exits with code `64`. If omitted, the CLI uses `en` if present, otherwise the first locale column.
  - `--sheet-name`: Specifies the name of the sheet to convert. If omitted, the first sheet in the file is used. Sheet names are case-sensitive (`Sheet1` and `sheet1` are treated as different sheets) and only a single sheet name may be provided. If the specified sheet does not exist, parsing will fail and the command will exit with an error. This option is honored by all exporters.
  - `--description-header`: Header text to locate the description column in the first row of the sheet. If provided, the CLI searches the first row for this exact header text and uses the matching column as the per-key description source. Behavior summary:
    - When the header is found, that column is read and each row's value becomes the `description` for the corresponding key.
    - The description column is excluded from the locale columns when detecting locales.
    - If the specified header text is not found, the command exits with an error.
    - Descriptions are emitted only into the effective default locale's ARB file as `@<key>` metadata. An `@<key>` object is emitted for each entry in that default-locale ARB file (it will be empty if no description is present).
      When you rely on the default `defaultLocale` value (for example, `defaultLocale = 'en'` in the library helpers), metadata is emitted for `en` only if a locale column named `en` exists; otherwise the locale column selected as the effective default (such as the first locale column when `en` is absent) is the one that receives the `@<key>` metadata. Non-default locale ARB files do not include `@<key>` metadata.
  - `--auto-detect-placeholders`: When set, the CLI scans message bodies for named placeholders like `{name}` and treats them as placeholders even when not explicitly declared in the sheet.
  - `--treat-undefined-placeholders`: One of `warn|ignore|add|error`. Controls how the CLI reacts when a detected placeholder is not declared in the sheet. Requires `--auto-detect-placeholders` to have effect. Behavior:
    - `warn` (default): log a warning for each undefined placeholder.
    - `ignore`: do nothing.
    - `add`: auto-add placeholder metadata to the in-memory model and include it in the emitted ARB (uses `--placeholder-default-type` for `type`).
    - `error`: abort with exit code `1` on first undefined placeholder.
  - `--placeholder-default-type`: Default type to assign when auto-adding placeholders (default: `String`).
  - Notes on ARB output and placeholders: when placeholder metadata exists for an entry, the ARB exporter includes a metadata object under `@<key>.placeholders` in the default-locale ARB file. Each placeholder object contains at least a `type` and may include `example` and `source` (e.g. `detected` or `declared`).

- Main public API:
  - `convertExcelToArb({required String inputPath, required String outDir, ExcelParser? parser, LocalizationExporter? exporter, String defaultLocale = 'en', String? sheetName, String? descriptionHeader})`
  - `convertExcelBytesToArb(Uint8List bytes, LocalizationExporter exporter, String outDir, {ExcelParser? parser, String defaultLocale = 'en', String? sheetName, String? descriptionHeader})`
  - `ExportCommand` — can be registered with a `CommandRunner` to run the CLI programmatically.

Both helper functions accept an optional `sheetName` parameter. When provided that sheet name is parsed; when `null` (or omitted) the first sheet in the workbook is used. If the specified sheet is not present a `SheetNotFoundException` is thrown (the CLI prints available sheets and exits with code `64`).

## Examples

See the `example/` directory for sample XLSX files and example usage.

## Exit Codes & Error Handling

- `64` — argument error / UsageException
- `1` — runtime error (file I/O, parsing errors, etc.)

## Troubleshooting (quick)

- If you see `Failed to parse arguments.`: check that required options (e.g. `--input`) are provided and correctly spelled.
- If you see `Unsupported format: <format>`: ensure `--format` is one of the supported formats (default: `arb`).
- If you see `Specified sheet "<name>" not found.`: verify the sheet name (case-sensitive) and list available sheets with a quick inspect of the XLSX.
- If you see `An error occurred: <details>`: run the command again with a valid input file and check file permissions.

## License

MIT
