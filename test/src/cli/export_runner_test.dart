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

/// Parser that throws when getting sheet names to simulate failure
class _SheetListFailureParser extends ExcelParser {
  _SheetListFailureParser(this.sheet);
  final LocalizationSheet sheet;

  @override
  LocalizationSheet parse(
    List<int> bytes, {
    String? sheetName,
    String? descriptionHeader,
  }) {
    return sheet;
  }

  @override
  List<String> getSheetNames(Uint8List bytes) {
    throw Exception('Failed to read workbook structure');
  }
}

/// Parser with empty sheet list but successful parsing
class _EmptySheetListParser extends ExcelParser {
  _EmptySheetListParser(this.sheet);
  final LocalizationSheet sheet;

  @override
  LocalizationSheet parse(
    List<int> bytes, {
    String? sheetName,
    String? descriptionHeader,
  }) {
    return sheet;
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

  test(
    'logs "(failed to list sheets)" when getSheetNames throws '
    'but parsing succeeds',
    () async {
      final logger = TestLogger();
      final sheet = LocalizationSheet(locales: const ['en', 'ja'], entries: []);
      final parser = _SheetListFailureParser(sheet);
      final exporter = _FakeExporter();

      final tmp = File('test/tmp_export_runner6.xlsx');
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
        // Logger should have logged with
        // "(failed to list sheets)" as the sheet name
        final infoMessages = logger.infos.join(' ');
        expect(infoMessages, contains('(failed to list sheets)'));
      } finally {
        await tmp.delete();
      }
    },
  );

  test(
    'logs "(workbook has no sheets)" when getSheetNames returns empty list',
    () async {
      final logger = TestLogger();
      final sheet = LocalizationSheet(locales: const ['en', 'ja'], entries: []);
      final parser = _EmptySheetListParser(sheet);
      final exporter = _FakeExporter();

      final tmp = File('test/tmp_export_runner7.xlsx');
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
        // Logger should have logged with
        // "(workbook has no sheets)" as the sheet name
        final infoMessages = logger.infos.join(' ');
        expect(infoMessages, contains('(workbook has no sheets)'));
      } finally {
        await tmp.delete();
      }
    },
  );

  test('auto-detect warn does not add placeholder but logs warning', () async {
    final logger = TestLogger();
    final entry = LocalizationEntry('items_count', const {
      'en': 'You have {count} items.',
    });
    final sheet = LocalizationSheet(locales: const ['en'], entries: [entry]);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_warn.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = ExportCommand().argParser.parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--auto-detect-placeholders',
        '--treat-undefined-placeholders',
        'warn',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(0));
      expect(exporter.lastSheet, isNotNull);
      final outEntry = exporter.lastSheet!.entries.first;
      expect(outEntry.placeholders.isEmpty, isTrue);
      expect(logger.infos.any((s) => s.contains('WARNING:')), isTrue);
    } finally {
      await tmp.delete();
    }
  });

  test('auto-detect add actually adds placeholder metadata', () async {
    final logger = TestLogger();
    final entry = LocalizationEntry('items_count', const {
      'en': 'You have {count} items.',
    });
    final sheet = LocalizationSheet(locales: const ['en'], entries: [entry]);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_add.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = ExportCommand().argParser.parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--auto-detect-placeholders',
        '--treat-undefined-placeholders',
        'add',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(0));
      final outEntry = exporter.lastSheet!.entries.first;
      expect(outEntry.placeholders.containsKey('count'), isTrue);
      expect(outEntry.placeholders['count']!.type, equals('String'));
    } finally {
      await tmp.delete();
    }
  });

  test('auto-detect add accumulates multiple placeholders', () async {
    final logger = TestLogger();
    final entry = LocalizationEntry('greet_both', const {
      'en': 'Hello {first} and {second}!',
    });
    final sheet = LocalizationSheet(locales: const ['en'], entries: [entry]);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_multi.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = ExportCommand().argParser.parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--auto-detect-placeholders',
        '--treat-undefined-placeholders',
        'add',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(0));
      final outEntry = exporter.lastSheet!.entries.first;
      expect(outEntry.placeholders.containsKey('first'), isTrue);
      expect(outEntry.placeholders.containsKey('second'), isTrue);
    } finally {
      await tmp.delete();
    }
  });

  test('auto-detect ignore does not log warning and does not add', () async {
    final logger = TestLogger();
    final entry = LocalizationEntry('items_count', const {
      'en': 'You have {count} items.',
    });
    final sheet = LocalizationSheet(locales: const ['en'], entries: [entry]);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_ignore.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = ExportCommand().argParser.parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--auto-detect-placeholders',
        '--treat-undefined-placeholders',
        'ignore',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(0));
      final outEntry = exporter.lastSheet!.entries.first;
      expect(outEntry.placeholders.isEmpty, isTrue);
      expect(logger.infos.any((s) => s.contains('WARNING:')), isFalse);
    } finally {
      await tmp.delete();
    }
  });
}
