# CHANGE LOG

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
