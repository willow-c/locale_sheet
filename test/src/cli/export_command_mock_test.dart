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

  @override
  LocalizationSheet parse(Uint8List bytes, {String? sheetName}) {
    lastSheetName = sheetName;
    return sheet;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      LocalizationSheet(locales: const [], entries: const []),
    );
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

    // Act
    final res = await runner.run([
      'export',
      '--input',
      tmp.path,
      '--out',
      'outdir',
    ]);
    await tmp.delete();

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
    await tmp.delete();

    // Assert
    expect(res, 0);
    expect(parser.lastSheetName, equals('MySpecialSheet'));
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
      await tmp.delete();

      // Assert
      expect(res, 64);
      expect(logger.errors, isNotEmpty);
      expect(logger.errors.first, contains(missingName));
      expect(logger.errors.first, contains('SheetA'));
    },
  );
}

class _ThrowingParser extends ExcelParser {
  _ThrowingParser(this.requested, this.available);
  final String requested;
  final List<String> available;

  @override
  LocalizationSheet parse(Uint8List bytes, {String? sheetName}) {
    throw SheetNotFoundException(requested, available);
  }
}
