# Sample Excel file

[README (English)](./README.md) | [README (日本語)](./README_ja.md)

This file contains sample data used for testing and verifying the behavior of the `locale_sheet` package.

- `sample.xlsx` — an example workbook that can be opened and edited with Excel. It contains two sheets: `Sheet1` covers locale columns, a description column and a non-locale column, while `Sheet2` is a minimal sheet with a different locale set (useful for trying `--sheet-name`).

## Contents

### Sheet1

|key|en|ja|zh|zh_TW|zh-Hant-HK|description|備考|
|:--|:--|:--|:--|:--|:--|:--|:--|
|hello|Hello|こんにちは|你好|你好|你好|the text 'Hello'|こんにちはの文言|
|bye|Goodbye|さようなら|再见|再見|再見|the text 'Goodbye'|さようならの文言|
|likeFoodFluit|I like {food} and {fluit}.|私は{food}と{fluit}が好き|我喜欢{food}和{fluit}|我喜歡{food}和{fluit}|我喜歡{food}和{fluit}|||

The `likeFoodFluit` row contains `{food}` / `{fluit}` placeholders and is the row to use when trying `--auto-detect-placeholders`. Its `description` and `備考` cells are intentionally empty.

### Sheet2

|key|ja|fr|
|:--|:--|:--|
|hello|こんにちは|Bonjour|
|bye|さようなら|Au revoir|

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
dart run locale_sheet export --input example/sample.xlsx --format arb --out ./lib/l10n --sheet-name Sheet1 --default-locale en --description-header description
```

- Input file: `example/sample.xlsx`
- Output format: `arb`
- Output directory: `./lib/l10n`
- Target sheet: `Sheet1`
- Default locale: `en`
- Description header: `description`
