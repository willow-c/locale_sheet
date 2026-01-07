import 'dart:convert';
import 'dart:io';

import 'package:locale_sheet/src/core/model.dart';
import 'package:locale_sheet/src/exporters/exporter.dart';

/// ARB エクスポーターの実装。
class ArbExporter implements LocalizationExporter {
  @override
  Future<void> export(
    LocalizationSheet sheet,
    String outDir, {
    String? defaultLocale,
  }) async {
    final dir = Directory(outDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    // For each target locale, build ARB content. If a translation is missing
    // and `defaultLocale` is provided, fall back to the default locale's
    // translation when available.
    for (final locale in sheet.locales) {
      final arb = <String, dynamic>{};
      for (final entry in sheet.entries) {
        var value = entry.translations[locale];
        if (value == null && defaultLocale != null) {
          value = entry.translations[defaultLocale];
        }
        if (value != null) {
          arb[entry.key] = value;
        }
      }
      arb['@@locale'] = locale;

      // Sort keys for stable output; keep @@locale at the end.
      final keys = arb.keys.where((k) => k != '@@locale').toList()..sort();
      final sorted = <String, dynamic>{};
      for (final k in keys) {
        sorted[k] = arb[k];
      }
      sorted['@@locale'] = arb['@@locale'];

      final fileName = 'app_$locale.arb';
      final file = File('${dir.path}/$fileName');
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(sorted));
    }
  }
}
