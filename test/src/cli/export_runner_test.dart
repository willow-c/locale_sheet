import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:locale_sheet/locale_sheet.dart';
import 'package:locale_sheet/src/cli/export_runner.dart';
import 'package:test/test.dart';

import '../../test_helpers/logger.dart';

class _FakeExporter implements LocalizationExporter {
  String? lastOutDir;
  LocalizationSheet? lastSheet;
  String? lastDefaultLocale;

  @override
  Future<void> export(
    LocalizationSheet sheet,
    String outDir, {
    String? defaultLocale,
  }) async {
    lastSheet = sheet;
    lastOutDir = outDir;
    lastDefaultLocale = defaultLocale;
  }
}

class _FakeParser extends ExcelParser {
  _FakeParser(this.sheet, {this.sheets = const <String>[]});
  final LocalizationSheet sheet;
  final List<String> sheets;

  @override
  LocalizationSheet parse(
    List<int> bytes, {
    String? sheetName,
    String? descriptionHeader,
  }) {
    return sheet;
  }

  @override
  List<String> getSheetNames(Uint8List bytes) => sheets;
}

class _ThrowingParser extends ExcelParser {
  _ThrowingParser(this.requested, this.available);
  final String requested;
  final List<String> available;

  @override
  LocalizationSheet parse(
    List<int> bytes, {
    String? sheetName,
    String? descriptionHeader,
  }) {
    throw SheetNotFoundException(requested, available);
  }

  @override
  List<String> getSheetNames(Uint8List bytes) => available;
}

class _FormatThrowingParser extends ExcelParser {
  @override
  LocalizationSheet parse(
    List<int> bytes, {
    String? sheetName,
    String? descriptionHeader,
  }) {
    throw const FormatException('bad format');
  }

  @override
  List<String> getSheetNames(Uint8List bytes) => <String>[];
}

void main() {
  ArgParser argParser() => ArgParser()
    ..addOption('input')
    ..addOption('format')
    ..addOption('out')
    ..addOption('sheet-name')
    ..addOption('default-locale')
    ..addOption('description-header')
    ..addFlag('color', defaultsTo: true);

  test('run returns 0 and calls exporter on success', () async {
    final logger = TestLogger();
    final sheet = LocalizationSheet(locales: const ['en', 'ja'], entries: []);
    final parser = _FakeParser(sheet, sheets: ['Sheet1', 'Sheet2']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(0));
      expect(exporter.lastOutDir, equals('outdir'));
      expect(exporter.lastSheet, isNotNull);
      expect(logger.infos.any((s) => s.startsWith('Result: Success')), isTrue);
    } finally {
      await tmp.delete();
    }
  });

  test('returns 64 when format unsupported', () async {
    final logger = TestLogger();
    final sheet = LocalizationSheet(locales: const ['en'], entries: []);
    final parser = _FakeParser(sheet);

    final tmp = File('test/tmp_export_runner2.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'unsupported',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': _FakeExporter()},
      );

      final res = await runner.run(args);
      expect(res, equals(64));
      expect(logger.errors, isNotEmpty);
      expect(logger.errors.first, contains('Unsupported format'));
    } finally {
      await tmp.delete();
    }
  });

  test('returns 64 when sheet not found', () async {
    final logger = TestLogger();
    final parser = _ThrowingParser('Missing', ['SheetA', 'SheetB']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner3.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--sheet-name',
        'Missing',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(64));
      expect(logger.errors.first, contains('Missing'));
      expect(logger.errors.first, contains('SheetA'));
    } finally {
      await tmp.delete();
    }
  });

  test('returns 64 when provided default-locale is invalid', () async {
    final logger = TestLogger();
    final sheet = LocalizationSheet(locales: const ['ja'], entries: []);
    final parser = _FakeParser(sheet);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner4.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(64));
      expect(logger.errors.first, contains('Specified default-locale'));
    } finally {
      await tmp.delete();
    }
  });

  test('returns 1 when parser throws FormatException', () async {
    final logger = TestLogger();
    final parser = _FormatThrowingParser();
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner5.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(1));
      expect(logger.errors.first, contains('An error occurred'));
    } finally {
      await tmp.delete();
    }
  });
}
