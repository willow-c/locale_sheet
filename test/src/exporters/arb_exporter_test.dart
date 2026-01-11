import 'dart:convert';
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
      LocalizationEntry('hello', const {'en': 'Hello', 'ja': 'こんにちは'}),
      LocalizationEntry('bye', const {'en': 'Goodbye', 'ja': null}),
    ];
    final sheet = LocalizationSheet(
      locales: const ['en', 'ja'],
      entries: entries,
    );
    final tmp = Directory.systemTemp.createTempSync('arb_export_test');
    final outDir = '${tmp.path}/out';
    final exporter = ArbExporter();

    try {
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
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  test('ArbExporter normalizes locale tags for filenames', () async {
    // Arrange
    final entries = [
      LocalizationEntry('greet', const {'zh_Hant_TW': '您好'}),
    ];
    final sheet = LocalizationSheet(
      locales: const ['zh_Hant_TW'],
      entries: entries,
    );
    final tmp = Directory.systemTemp.createTempSync('arb_export_norm_test');
    final outDir = '${tmp.path}/out';
    final exporter = ArbExporter();

    try {
      // Act
      await exporter.export(sheet, outDir);

      // Assert: filename uses '_' for ARB filenames (Flutter convention)
      final normalizedFile = File('$outDir/app_zh_Hant_TW.arb');
      expect(normalizedFile.existsSync(), isTrue);
      final content = normalizedFile.readAsStringSync();
      // Ensure @@locale in the content matches the locale tag
      // used in sheet.locales.
      expect(content.contains('"@@locale"'), isTrue);
      expect(content.contains('zh_Hant_TW'), isTrue);
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  test('ArbExporter throws on invalid locale tag', () async {
    // Arrange: include an invalid locale that is unsafe for filenames
    final entries = [
      LocalizationEntry('k', const {'en': 'ok'}),
    ];
    final sheet = LocalizationSheet(
      locales: const ['in/valid'],
      entries: entries,
    );
    final tmp = Directory.systemTemp.createTempSync('arb_export_invalid_test');
    final outDir = '${tmp.path}/out';
    final exporter = ArbExporter();

    try {
      // Act & Assert
      expect(exporter.export(sheet, outDir), throwsFormatException);
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  test('ArbExporter rejects Windows reserved locale tags', () async {
    // Arrange: locale equal to Windows reserved name
    final entries = [
      LocalizationEntry('k', const {'CON': 'x'}),
    ];
    final sheet = LocalizationSheet(
      locales: const ['CON'],
      entries: entries,
    );
    final tmp = Directory.systemTemp.createTempSync('arb_export_win_test');
    final outDir = '${tmp.path}/out';
    final exporter = ArbExporter();

    try {
      // Act & Assert
      expect(exporter.export(sheet, outDir), throwsFormatException);
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  test('ArbExporter writes @@locale with underscores', () async {
    // Arrange
    final entries = [
      LocalizationEntry('greet', const {'zh-Hant-HK': '您好'}),
    ];
    final sheet = LocalizationSheet(
      locales: const ['zh-Hant-HK'],
      entries: entries,
    );
    final tmp = Directory.systemTemp.createTempSync('arb_underscore_test');
    final outDir = '${tmp.path}/out';
    final exporter = ArbExporter();

    try {
      // Act
      await exporter.export(sheet, outDir);

      // Assert: file exists and @@locale uses underscores
      final file = File('$outDir/app_zh_Hant_HK.arb');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('"@@locale"'), isTrue);
      expect(content.contains('zh_Hant_HK'), isTrue);
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  test(
    'ArbExporter falls back to defaultLocale when translation missing',
    () async {
      // Arrange
      final entries = [
        LocalizationEntry('welcome', const {'en': 'Welcome', 'ja': null}),
      ];
      final sheet = LocalizationSheet(
        locales: const ['ja'],
        entries: entries,
      );
      final tmp = Directory.systemTemp.createTempSync('arb_default_fallback');
      final outDir = '${tmp.path}/out';
      final exporter = ArbExporter();

      try {
        // Act
        await exporter.export(sheet, outDir, defaultLocale: 'en');

        // Assert: ja file contains the English fallback
        final jaFile = File('$outDir/app_ja.arb');
        expect(jaFile.existsSync(), isTrue);
        final jaContent = jaFile.readAsStringSync();
        expect(jaContent.contains('Welcome'), isTrue);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    },
  );

  test('ArbExporter emits empty @key objects when no description', () async {
    final entries = [
      LocalizationEntry('hello', const {'en': 'Hello', 'ja': 'こんにちは'}),
    ];
    final sheet = LocalizationSheet(
      locales: const ['en', 'ja'],
      entries: entries,
    );
    final tmp = Directory.systemTemp.createTempSync('arb_desc_empty');
    final outDir = '${tmp.path}/out';
    final exporter = ArbExporter();

    try {
      await exporter.export(sheet, outDir, defaultLocale: 'en');

      final enFile = File('$outDir/app_en.arb');
      expect(enFile.existsSync(), isTrue);
      final content = enFile.readAsStringSync();

      // Parse the ARB as JSON to verify structure and ordering
      final obj = jsonDecode(content) as Map<String, dynamic>;
      expect(obj.containsKey('hello'), isTrue);
      expect(obj.containsKey('@hello'), isTrue);

      // Verify metadata object is immediately before the translation key
      final keys = obj.keys.toList();
      final metaIndex = keys.indexOf('@hello');
      final keyIndex = keys.indexOf('hello');
      expect(metaIndex, greaterThanOrEqualTo(0));
      expect(keyIndex, greaterThanOrEqualTo(0));
      expect(metaIndex, equals(keyIndex - 1));

      // Metadata should be a JSON object (may be empty)
      expect(obj['@hello'], isA<Map<String, dynamic>>());
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  test('ArbExporter includes description in @key when present', () async {
    final entries = [
      LocalizationEntry('bye', const {
        'en': 'Goodbye',
      }, description: 'Farewell'),
    ];
    final sheet = LocalizationSheet(locales: const ['en'], entries: entries);
    final tmp = Directory.systemTemp.createTempSync('arb_desc_present');
    final outDir = '${tmp.path}/out';
    final exporter = ArbExporter();

    try {
      await exporter.export(sheet, outDir, defaultLocale: 'en');

      final enFile = File('$outDir/app_en.arb');
      expect(enFile.existsSync(), isTrue);
      final content = enFile.readAsStringSync();

      // Parse to JSON and assert metadata includes description and ordering
      final obj = jsonDecode(content) as Map<String, dynamic>;
      expect(obj.containsKey('bye'), isTrue);
      expect(obj.containsKey('@bye'), isTrue);

      final keys = obj.keys.toList();
      final metaIndex = keys.indexOf('@bye');
      final keyIndex = keys.indexOf('bye');
      expect(metaIndex, equals(keyIndex - 1));

      final meta = obj['@bye'] as Map<String, dynamic>;
      expect(meta, isA<Map<String, dynamic>>());
      expect(meta['description'], equals('Farewell'));
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });
}
