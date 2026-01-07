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

  @override
  LocalizationSheet parse(Uint8List bytes) => sheet;
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      LocalizationSheet(locales: const [], entries: const []),
    );
  });

  test('ExportCommand calls injected exporter (mocktail)', () async {
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
    final res = await runner.run([
      'export',
      '--input',
      tmp.path,
      '--out',
      'outdir',
    ]);
    await tmp.delete();

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
}
