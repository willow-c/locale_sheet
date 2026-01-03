import 'dart:convert';
import 'dart:io';

import '../core/model.dart';
import 'exporter.dart';

/// ARB エクスポーターの実装。
class ArbExporter implements LocalizationExporter {
  @override
  Future<void> export(LocalizationSheet sheet, String outDir) async {
    final dir = Directory(outDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    for (final locale in sheet.locales) {
      final Map<String, dynamic> arb = {};
      for (final entry in sheet.entries) {
        final value = entry.translations[locale];
        if (value != null) {
          arb[entry.key] = value;
        }
      }
      arb['@@locale'] = locale;

      // 出力を安定化するためにキーをソートします。'@@locale' は末尾に配置します。
      final keys = arb.keys.where((k) => k != '@@locale').toList()..sort();
      final sorted = <String, dynamic>{};
      for (final k in keys) {
        sorted[k] = arb[k];
      }
      sorted['@@locale'] = arb['@@locale'];

      final fileName = 'app_$locale.arb';
      final file = File('${dir.path}/$fileName');
      final encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(sorted));
    }
  }
}
