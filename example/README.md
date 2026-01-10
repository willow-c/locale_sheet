# Sample Excel file

[README (English)](./README.md) | [README (日本語)](./README_ja.md)

This file contains sample data used for testing and verifying the behavior of the `locale_sheet` package.

- `sample.xlsx` — a simple example (columns: `key`, `en`, `ja`) that can be opened and edited with Excel.

## Contents

|key|en|ja|zh|zh_TW|zh-Hant-HK|description|備考|
|:--|:--|:--|:--|:--|:--|:--|:--|
|hello|Hello|こんにちは|你好|你好|你好|the text 'Hello'|こんにちはの文言|
|bye|Goodbye|さようなら|再见|再見|再見|the text 'Goodbye'|さようならの文言|

## Locale column detection rules

- Only header cells that look like locale tags are treated as locale columns; non-locale columns (for example `description` or `notes`) are ignored for resource output.
- Incoming tags may use either `-` or `_` as separators; these are treated equivalently (e.g. `zh-Hant-HK` and `zh_Hant_HK` are considered the same).
- Comparisons are case-insensitive. The implementation trims whitespace and normalizes separators for validation; see `lib/src/core/model_helpers.dart` (`normalizeLocaleTag` / `isValidLocaleTag`) for details.

## ARB output behavior

- ARB filenames follow the Flutter convention and use underscores in place of hyphens. For example, locale headers `en`, `zh_TW`, `zh-Hant-HK` will produce:
  - `app_en.arb`
  - `app_zh_TW.arb`
  - `app_zh_Hant_HK.arb`
- The `@@locale` field in each generated ARB uses the normalized locale tag (with underscores, matching the ARB filename), not the raw header string.
- Tags that would create invalid filenames on Windows (reserved names such as `CON`, `PRN`, `AUX`, `NUL`, `COM1`, etc., or names ending with a space or dot) are rejected by the exporter.

## `key` column

- The header row must include a `key` column; values in that column become the resource keys in exported files.

## CLI example

```sh
dart run locale_sheet export --input example/sample.xlsx --format arb --out ./lib/l10n --default-locale en
```

This command reads the sample sheet and writes ARB files to `./lib/l10n` when locale columns are present. The sample sheet itself is a small demo and does not represent production localization data.
