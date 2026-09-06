# CHANGE LOG

## vx.x.x 20xx-xx-xx

- change: `ExcelParser` now uses a focused built-in XLSX reader instead of the `excel` package at runtime. The optional `decoder` constructor argument has been removed; code that injected an `Excel` decoder must pass XLSX bytes through the normal parser path or provide an `ExcelParser` implementation at the caller boundary.
- change: runtime dependencies changed. `archive: ^3.6.1` and `xml: ^6.6.1` are now runtime dependencies, and `excel` is used only to build test fixtures. Applications that already depend on `archive: ^4.0.0` or `xml: ^7.0.0` cannot resolve this version; the constraints stay narrow until the reader can be verified against those major versions.
- fix: XLSX files containing duplicate entries in `sharedStrings.xml` no longer fail with `Null check operator used on a null value` or shift subsequent cell values. Shared-string positions and duplicates are now preserved exactly while reading.
- fix: numbers whose format contains a colour, currency, or condition section (for example `[Red]#,##0.00`) are no longer misread as dates or times. Only the parts of a format code that specify a date or time are considered.
- fix: date and time cells that use an East Asian builtin number format (`numFmtId` 27–36 and 50–58, such as `yyyy"年"m"月"d"日"`) are converted like other date cells instead of being emitted as a raw serial number.
- fix: worksheets that omit the optional row and cell position attributes (`row@r` / `c@r`) are read in document order instead of being reported as an empty sheet.
- fix: cells belonging to a shared formula now export their stored value instead of a bare `=`.
- fix: workbooks written with namespace prefixes (`<x:sheet>`, `<pkg:Relationship>`) are read instead of failing with a sheet-not-found error that lists no sheets.
- fix: `date1904="true"` is recognised as the 1904 date system, so dates in such workbooks are no longer shifted by 1462 days.
- fix: boolean cells written as `<v>true</v>` are no longer reported as `false`.
- fix: inline strings no longer include phonetic hints (`rPh`) in their text, matching how shared strings are read.
- fix: elapsed-time formats (`[h]:mm:ss` and `numFmtId` 46) no longer wrap at 24 hours; 30 hours is exported as `30:00:00`.
- fix: an out-of-range style index on a cell no longer escapes as a `RangeError`; such cells are read without a number format.

## 0.5.0 - 2026-07-29

This release contains breaking changes. The `change:` entries below list them first.

- change: **exit codes now follow the BSD `sysexits.h` convention and `1` is no longer used.** Previously the same kind of mistake could produce either `1` or `64` depending on which exception type happened to surface — for example a missing `--sheet-name` gave `64` while a missing `--description-header` gave `1`. Now: `64` for command line errors, `65` for input that does not match what you asked for, `66` when the input cannot be read, `73` when the output cannot be written, `70` for unexpected internal errors (previously an uncaught `Error` exited `255` with no documented meaning). The line between `64` and `65` is whether the mistake can be seen without opening the input file. Scripts that branch on the exit code need updating; scripts that only check for zero are unaffected.
- change: warnings now go to stderr instead of stdout, and the `WARNING:` prefix is added by the log level rather than written into each message. This affects the duplicate-key, undeclared-placeholder and ineffective-option warnings. If you were grepping stdout for `WARNING:`, read stderr instead. Library users implementing `Logger` must add a `warn` method.
- change: the lists held by `LocalizationSheet` (`locales`, `entries`, `ignoredHeaders`) are now unmodifiable. Code that mutated them in place must build a new sheet instead.
- feat: add `--locales` (and a `locales` parameter on `convertExcelToArb` / `convertExcelBytesToArb`) to name the locale columns explicitly, e.g. `--locales en,ja`. Automatic detection is permissive — any 2–8 letter header such as `memo` or `note` qualifies as a locale — so sheets with extra columns previously produced files like `app_memo.arb`. A requested tag missing from the header row is now an error rather than a silently dropped language. Omitting the option keeps the previous behavior.
- feat: the CLI now always logs which columns were selected as locales and which were ignored, and `LocalizationSheet.ignoredHeaders` exposes the ignored headers to library users.
- feat: add `ExcelParser.parseWorkbook`, which returns the parsed sheet together with the name of the sheet it read and the names of all sheets in the workbook. The CLI uses it to decode the workbook once per run instead of twice. `parse` is unchanged and now delegates to it. Code that subclassed `ExcelParser` to override `parse` must override `parseWorkbook` instead.
- feat: expose `PlaceholderResolver`, which detects undeclared placeholders in a `LocalizationSheet` and optionally adds them, returning a new sheet rather than modifying the input. The CLI now uses it instead of doing the work inline.
- feat: warn when the same key appears in more than one row. `LocalizationSheet.duplicateKeys` exposes the list for library users. Export behavior is unchanged (later rows still win per locale).
- fix: reject locale columns that refer to the same locale instead of silently losing one of them. `zh-TW` and `zh_TW`, or `en` and `EN`, both map to the same ARB filename, so the later column used to overwrite the earlier one. Case-only differences additionally produced different output on case-sensitive and case-insensitive filesystems.
- fix: the CLI now fails with `65` when the sheet has no locale columns, instead of reporting success after writing no files at all. The error names the ignored columns and points at `--locales`. The library API is unchanged and still accepts a sheet with no locales.
- fix: running the CLI with no command at all now prints the usage to stderr and exits with `64` instead of exiting `0` without doing anything. Asking for help explicitly (`--help`, `help`) still exits `0`.
- fix: `ArbExporter` now validates every locale before writing anything, so a rejected locale tag no longer leaves ARB files for the locales processed before it, and no longer creates the output directory.
- fix: `LocalizationEntry` equality and `hashCode` now compare placeholders by value. Two entries holding identical placeholders previously never compared equal, because each comparison converted the placeholders to fresh `Map` instances. Entries without placeholders were unaffected.
- docs: fix the Quick Start dependency snippet in `README.md` / `README_ja.md` — `locale_sheet` was not indented under `dev_dependencies`, so the snippet was invalid YAML as written.
- docs: document the `--color` / `--no-color` option, which was missing from the CLI option list in both READMEs.
- docs: correct the `--description-header` description in `README.md` / `README_ja.md` — matching ignores surrounding whitespace and is case-insensitive, so calling it an "exact" match was wrong.
- docs: sync `example/README.md` / `example/README_ja.md` with the actual `sample.xlsx` — add the missing `likeFoodFluit` row (the placeholder sample) and replace the stale "columns: key, en, ja" summary.
- chore: drop the `path` dependency, which was declared in `pubspec.yaml` but never imported anywhere in the package.

## 0.4.1 - 2026-02-25

- chore: downgrade Flutter SDK version to 3.9.0 ([#33](https://github.com/willow-c/locale_sheet/pull/33))

## 0.4.0 - 2026-01-20

- feat: add auto-detect placeholders for the `export` command; new CLI options `--auto-detect-placeholders` and `--treat-undefined-placeholders` to control handling of undefined placeholders; updates to documentation and examples ([#24](https://github.com/willow-c/locale_sheet/pull/24))
- feat: accumulate multiple placeholders detected in a single string during auto-detection (improves placeholder merging in exports)
- feat: update `example/sample.xlsx` used by CLI and tests ([#28](https://github.com/willow-c/locale_sheet/pull/28))

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
