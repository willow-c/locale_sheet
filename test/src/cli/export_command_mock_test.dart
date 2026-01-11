import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:locale_sheet/locale_sheet.dart';
import 'package:locale_sheet/src/cli/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockExporter extends Mock implements LocalizationExporter {}

class TestLogger implements Logger {
  final infos = <String>[];
  final errors = <String>[];

  @override
  void info(String message) => infos.add(message);

  @override
  void error(String message) => errors.add(message);
}

class FakeParser extends ExcelParser {
  FakeParser(this.sheet);
  final LocalizationSheet sheet;
  String? lastSheetName;
  String? lastDescriptionHeader;

  @override
  LocalizationSheet parse(
    Uint8List bytes, {
    String? sheetName,
    String? descriptionHeader,
  }) {
    lastSheetName = sheetName;
    lastDescriptionHeader = descriptionHeader;
    return sheet;
  }

  @override
  List<String> getSheetNames(Uint8List bytes) => <String>[];
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      LocalizationSheet(locales: const [], entries: const []),
    );
  });

  test('ExportCommand forwards --description-header to parser', () async {
    // Arrange
    final logger = TestLogger();

    final sheet = LocalizationSheet(locales: const ['en'], entries: []);
    final parser = FakeParser(sheet);

    final mockExporter = MockExporter();
    when(
      () => mockExporter.export(
        any(),
        any(),
        defaultLocale: any(named: 'defaultLocale'),
      ),
    ).thenAnswer((_) async {});

    final cmd = ExportCommand(
      logger: logger,
      parser: parser,
      exporters: {'arb': mockExporter},
    );
    final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);

    final tmp = File('test/tmp_desc_forward.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      // Act
      final res = await runner.run([
        'export',
        '--input',
        tmp.path,
        '--out',
        'outdir',
        '--description-header',
        'description',
      ]);

      // Assert
      expect(res, 0);
      expect(parser.lastDescriptionHeader, equals('description'));
    } finally {
      await tmp.delete();
    }
  });

  test('ExportCommand returns 1 when description header not found', () async {
    // Arrange
    final logger = TestLogger();

    final parser = _FormatThrowingParser();

    final mockExporter = MockExporter();
    when(
      () => mockExporter.export(
        any(),
        any(),
        defaultLocale: any(named: 'defaultLocale'),
      ),
    ).thenAnswer((_) async {});

    final cmd = ExportCommand(
      logger: logger,
      parser: parser,
      exporters: {'arb': mockExporter},
    );
    final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);

    final tmp = File('test/tmp_desc_missing.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      // Act
      final res = await runner.run([
        'export',
        '--input',
        tmp.path,
        '--out',
        'outdir',
        '--description-header',
        'description',
      ]);

      // Assert: parser throws FormatException, CLI should return 1
      expect(res, equals(1));
      expect(logger.errors, isNotEmpty);
    } finally {
      await tmp.delete();
    }
  });

  test('ExportCommand calls injected exporter (mocktail)', () async {
    // Arrange
    final logger = TestLogger();

    final sheet = LocalizationSheet(
      locales: const ['en'],
      entries: [
        LocalizationEntry('k', const {'en': 'v'}),
      ],
    );
    final parser = FakeParser(sheet);

    final mockExporter = MockExporter();
    when(
      () => mockExporter.export(
        any(),
        any(),
        defaultLocale: any(named: 'defaultLocale'),
      ),
    ).thenAnswer((_) async {});

    final cmd = ExportCommand(
      logger: logger,
      parser: parser,
      exporters: {'arb': mockExporter},
    );
    final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);

    final tmp = File('test/tmp_mocktail.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      // Act
      final res = await runner.run([
        'export',
        '--input',
        tmp.path,
        '--out',
        'outdir',
      ]);

      // Assert
      expect(res, 0);
      verify(
        () => mockExporter.export(
          any(),
          'outdir',
          defaultLocale: any(named: 'defaultLocale'),
        ),
      ).called(1);
      expect(logger.infos, isNotEmpty);
    } finally {
      await tmp.delete();
    }
  });

  test('ExportCommand forwards --sheet-name to parser', () async {
    // Arrange
    final logger = TestLogger();

    final sheet = LocalizationSheet(locales: const ['en'], entries: []);
    final parser = FakeParser(sheet);

    final mockExporter = MockExporter();
    when(
      () => mockExporter.export(
        any(),
        any(),
        defaultLocale: any(named: 'defaultLocale'),
      ),
    ).thenAnswer((_) async {});

    final cmd = ExportCommand(
      logger: logger,
      parser: parser,
      exporters: {'arb': mockExporter},
    );
    final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);

    final tmp = File('test/tmp_sheetname.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      // Act
      final res = await runner.run([
        'export',
        '--input',
        tmp.path,
        '--out',
        'outdir',
        '--sheet-name',
        'MySpecialSheet',
      ]);

      // Assert
      expect(res, 0);
      expect(parser.lastSheetName, equals('MySpecialSheet'));
    } finally {
      await tmp.delete();
    }
  });

  test('ExportCommand.run returns 64 when argResults is null', () async {
    // Arrange
    final logger = TestLogger();
    final cmd = ExportCommand(
      logger: logger,
      parser: FakeParser(LocalizationSheet(locales: const [], entries: [])),
      exporters: {},
    );

    // Act
    final res = await cmd.run();

    // Assert
    expect(res, equals(64));
    expect(logger.errors.first, contains('Failed to parse arguments'));
  });

  test(
    'ExportCommand returns 64 when provided default-locale not in sheet',
    () async {
      // Arrange
      final logger = TestLogger();
      final sheet = LocalizationSheet(locales: const ['ja'], entries: []);
      final parser = FakeParser(sheet);

      final mockExporter = MockExporter();
      when(
        () => mockExporter.export(
          any(),
          any(),
          defaultLocale: any(named: 'defaultLocale'),
        ),
      ).thenAnswer((_) async {});

      final cmd = ExportCommand(
        logger: logger,
        parser: parser,
        exporters: {'arb': mockExporter},
      );
      final runner = CommandRunner<int>('locale_sheet', 'test')
        ..addCommand(cmd);

      final tmp = File('test/tmp_default_missing.xlsx');
      await tmp.writeAsBytes([0]);

      try {
        // Act
        final res = await runner.run([
          'export',
          '--input',
          tmp.path,
          '--out',
          'outdir',
          '--default-locale',
          'en',
        ]);

        // Assert
        expect(res, equals(64));
        expect(logger.errors.first, contains('Specified default-locale'));
      } finally {
        await tmp.delete();
      }
    },
  );

  test('ExportCommand returns 1 when exporter throws', () async {
    // Arrange
    final logger = TestLogger();
    final sheet = LocalizationSheet(locales: const ['en'], entries: []);
    final parser = FakeParser(sheet);

    final mockExporter = MockExporter();
    when(
      () => mockExporter.export(
        any(),
        any(),
        defaultLocale: any(named: 'defaultLocale'),
      ),
    ).thenThrow(Exception('boom'));

    final cmd = ExportCommand(
      logger: logger,
      parser: parser,
      exporters: {'arb': mockExporter},
    );
    final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);

    final tmp = File('test/tmp_exporter_throw.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      // Act
      final res = await runner.run([
        'export',
        '--input',
        tmp.path,
        '--out',
        'outdir',
      ]);

      // Assert
      expect(res, equals(1));
      expect(logger.errors.first, contains('An error occurred'));
    } finally {
      await tmp.delete();
    }
  });

  test(
    'ExportCommand logs available sheets and returns 64 when sheet missing',
    () async {
      final logger = TestLogger();

      // Arrange
      const missingName = 'Nope';
      const available = ['SheetA', 'SheetB'];

      // Use a small wrapper to replace parser.parse behavior
      final throwingParser = _ThrowingParser(missingName, available);

      final mockExporter = MockExporter();
      when(
        () => mockExporter.export(
          any(),
          any(),
          defaultLocale: any(named: 'defaultLocale'),
        ),
      ).thenAnswer((_) async {});

      final cmd = ExportCommand(
        logger: logger,
        parser: throwingParser,
        exporters: {'arb': mockExporter},
      );
      final runner = CommandRunner<int>('locale_sheet', 'test')
        ..addCommand(cmd);

      final tmp = File('test/tmp_sheetname2.xlsx');
      await tmp.writeAsBytes([0]);

      try {
        // Act
        final res = await runner.run([
          'export',
          '--input',
          tmp.path,
          '--out',
          'outdir',
          '--sheet-name',
          missingName,
        ]);

        // Assert
        expect(res, 64);
        expect(logger.errors, isNotEmpty);
        expect(logger.errors.first, contains(missingName));
        expect(logger.errors.first, contains('SheetA'));
      } finally {
        await tmp.delete();
      }
    },
  );
}

class _ThrowingParser extends ExcelParser {
  _ThrowingParser(this.requested, this.available);
  final String requested;
  final List<String> available;

  @override
  LocalizationSheet parse(
    Uint8List bytes, {
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
    Uint8List bytes, {
    String? sheetName,
    String? descriptionHeader,
  }) {
    throw const FormatException('Description header not found');
  }

  @override
  List<String> getSheetNames(Uint8List bytes) => <String>[];
}
