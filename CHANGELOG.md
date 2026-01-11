# CHANGE LOG

## 0.3.0 - 2026-01-11

- feat: enhance CLI logging with color output and structured messages ([#19](https://github.com/willow-c/locale_sheet/pull/19))
- feat: add description header support in locale_sheet export ([#17](https://github.com/willow-c/locale_sheet/pull/17))
- chore: update Flutter SDK version to 3.38.6 ([#15](https://github.com/willow-c/locale_sheet/pull/15))
- docs: fix formatting in README and README_ja for consistency ([#13](https://github.com/willow-c/locale_sheet/pull/13))
- chore: agents and scripts improvements ([#11](https://github.com/willow-c/locale_sheet/pull/11))
- chore: standardize CLI/runtime messages to English; update README and tests accordingly ([#10](https://github.com/willow-c/locale_sheet/pull/10))

## 0.2.0 - 2026-01-10

- refactor: update analysis options and improve code structure ([#3](https://github.com/willow-c/locale_sheet/pull/3))
- feat: implement locale validation and normalization functions ([#5](https://github.com/willow-c/locale_sheet/pull/5))
- feat: Add `--sheet-name` option for sheet selection and improve documentation ([#7](https://github.com/willow-c/locale_sheet/pull/7))

## 0.1.1 - 2026-01-06

- Fixed: Quick Start in `README.md` / `README_ja.md` — dependency example updated to `locale_sheet: ^0.1.1` (previously `^0.0.2`).

## 0.1.0 - 2026-01-06

- Added CLI option `--default-locale` (`-d`) to specify a fallback locale when translations are missing.
  - If `--default-locale` is provided and the locale does not exist in the sheet, the command exits with code `64` and prints an error.
  - If `--default-locale` is omitted, the CLI uses `en` if present in the sheet; otherwise it falls back to the first locale column. If no locale columns exist, `en` is used as a conservative default.
- Threaded `defaultLocale` through public API: `convertExcelToArb` / `convertExcelBytesToArb` now accept a `defaultLocale` parameter (default: `'en'`).
- `LocalizationExporter.export` signature now accepts a named `defaultLocale` argument. Update custom exporters if you implement your own exporter.
- `ArbExporter` now falls back to `defaultLocale` for missing translations.
- Documentation: updated `README.md` and `README_ja.md` with examples and notes for `--default-locale`.
- Tests: updated unit tests to reflect the new behavior.

## 0.0.1

- Initial version.
