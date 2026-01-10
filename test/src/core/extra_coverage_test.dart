import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:excel/excel.dart';
import 'package:locale_sheet/locale_sheet.dart';
import 'package:test/test.dart';

import '../../test_helpers/logger.dart';

void main() {
  test('Parser treats null cell value as empty string -> translation null', () {
    final excel = Excel.createExcel();
    excel['Sheet1']
      ..appendRow([TextCellValue('key'), TextCellValue('en')])
      ..appendRow([TextCellValue('hello'), null]);
    final bytes = excel.encode();
    final tmp = Directory.systemTemp.createTempSync('parser_null_cell');
    final file = File('${tmp.path}/nullcell.xlsx')..writeAsBytesSync(bytes!);

    final parser = ExcelParser();
    final sheetModel = parser.parse(file.readAsBytesSync());
    expect(sheetModel.locales, contains('en'));
    expect(sheetModel.entries.length, 1);
    expect(sheetModel.entries.first.translations['en'], isNull);

    tmp.deleteSync(recursive: true);
  });

  test('LocalizationEntry.fromMap handles non-map translations gracefully', () {
    final m = {'key': 'k', 'translations': 'not_a_map', 'description': 'd'};
    final e = LocalizationEntry.fromMap(m);
    expect(e.key, 'k');
    expect(e.description, 'd');
    expect(e.translations, isEmpty);
  });

  test('LocalizationEntry.copyWith preserves defaults when nulls passed', () {
    final e = LocalizationEntry('k', const {'en': 'v'}, description: 'd');
    final e2 = e.copyWith();
    expect(e2.key, 'k');
    expect(e2.translations['en'], 'v');
    expect(e2.description, 'd');
    final e3 = e.copyWith(key: 'k2');
    expect(e3.key, 'k2');
  });

  test('LocalizationBundle.fromMap skips null values', () {
    final b = LocalizationBundle.fromMap('en', const {'a': '1', 'b': null});
    expect(b['a'], '1');
    expect(b['b'], isNull);
    expect(b.toMap().containsKey('b'), isFalse);
  });

  test('LocalizationBundle.copyWith entries override works', () {
    final b = LocalizationBundle('en', const {'a': '1'});
    final b2 = b.copyWith(entries: const {'b': '2'});
    expect(b2['b'], '2');
    final b3 = b.copyWith();
    expect(b3['a'], '1');
  });

  test(
    'ExportCommand returns 64 when exporter missing (exporters map empty)',
    () async {
      final logger = TestLogger();
      final cmd = ExportCommand(logger: logger, exporters: {});
      final runner = CommandRunner<int>('locale_sheet', 'test')
        ..addCommand(cmd);

      final tmp = File('test/tmp_missing_exporter.xlsx')..writeAsBytesSync([0]);
      final res = await runner.run(['export', '--input', tmp.path]);
      await tmp.delete();

      expect(res, 64);
      expect(logger.errors.first, contains('Unsupported format'));
    },
  );
}
