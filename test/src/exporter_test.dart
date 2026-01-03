import 'dart:io';

import 'package:locale_sheet/src/core/model.dart';
import 'package:locale_sheet/src/exporters/arb_exporter.dart';
import 'package:test/test.dart';

void main() {
  /// ArbExporterが各ロケールごとにARBファイルを出力し、@@localeが含まれることを検証
  /// Arrange-Act-Assertパターン
  test('ArbExporter writes files and includes @@locale', () async {
    // Arrange
    final entries = [
      LocalizationEntry('hello', {'en': 'Hello', 'ja': 'こんにちは'}),
      LocalizationEntry('bye', {'en': 'Goodbye', 'ja': null}),
    ];
    final sheet = LocalizationSheet(locales: ['en', 'ja'], entries: entries);
    final tmp = Directory.systemTemp.createTempSync('arb_export_test');
    final outDir = '${tmp.path}/out';
    final exporter = ArbExporter();
    // Act
    await exporter.export(sheet, outDir);
    // Assert
    final enFile = File('$outDir/app_en.arb');
    final jaFile = File('$outDir/app_ja.arb');
    expect(enFile.existsSync(), isTrue);
    expect(jaFile.existsSync(), isTrue);

    final en = enFile.readAsStringSync();
    expect(en.contains('"@@locale"'), isTrue);
    expect(en.contains('Hello'), isTrue);

    final ja = jaFile.readAsStringSync();
    expect(ja.contains('"@@locale"'), isTrue);
    expect(ja.contains('こんにちは'), isTrue);
    // Cleanup
    tmp.deleteSync(recursive: true);
  });
}
