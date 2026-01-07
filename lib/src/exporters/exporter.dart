// Suppress suggestion to replace this single-method abstract class with
// a top-level function; we prefer an interface here for clarity and
// future extensibility.
// ignore_for_file: one_member_abstracts

import 'package:locale_sheet/src/core/model.dart';

/// [LocalizationSheet] をファイルに書き出すエクスポーターの共通インターフェース。
abstract class LocalizationExporter {
  /// Export `sheet` into `outDir`. Optionally provide `defaultLocale`.
  Future<void> export(
    LocalizationSheet sheet,
    String outDir, {
    String? defaultLocale,
  });
}
