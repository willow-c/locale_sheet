import 'dart:convert';
import 'dart:io';

import 'package:locale_sheet/src/core/model.dart';
import 'package:locale_sheet/src/core/model_helpers.dart';
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
      // Normalize and validate locale tag early to fail fast and avoid
      // building ARB content for invalid tags.
      final tag = normalizeLocaleTag(locale);
      if (!isSafeArbLocaleTag(tag)) {
        throw FormatException(
          'Locale tag "$locale" is not valid for ARB filename',
        );
      }
      final fileLocaleTag = tag.replaceAll('-', '_');

      final arb = <String, dynamic>{};
      final metadata = <String, dynamic>{};
      for (final entry in sheet.entries) {
        var value = entry.translations[locale];
        if (value == null && defaultLocale != null) {
          value = entry.translations[defaultLocale];
        }
        if (value != null) {
          // For default locale we always emit an @key metadata object
          // (possibly empty). If a description exists on the entry, include
          // it; otherwise metadata object stays empty.
          if (locale == defaultLocale) {
            final metaObj = <String, dynamic>{};
            if (entry.description != null && entry.description!.isNotEmpty) {
              metaObj['description'] = entry.description;
            }
            metadata['@${entry.key}'] = metaObj;
          }

          arb[entry.key] = value;
        }
      }

      // Use underscore-separated tag for ARB @@locale to match filename.
      arb['@@locale'] = fileLocaleTag;

      // Sort keys for stable output; keep @@locale at the end.
      // Build a stable ordering where for the default locale we emit the
      // metadata entries (`@key`) immediately before their corresponding
      // translation keys. Non-default locales do not include metadata.
      final keys = arb.keys.where((k) => k != '@@locale').toList()..sort();
      final sorted = <String, dynamic>{};
      for (final k in keys) {
        if (locale == defaultLocale) {
          final metaKey = '@$k';
          final meta = metadata[metaKey];
          if (meta != null) sorted[metaKey] = meta;
        }
        sorted[k] = arb[k];
      }
      sorted['@@locale'] = arb['@@locale'];

      // For ARB filenames follow Flutter convention: use underscores.
      final fileName = 'app_$fileLocaleTag.arb';
      final file = File('${dir.path}/$fileName');
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(sorted));
    }
  }
}
