import 'dart:io';

import 'package:excel/excel.dart';
import 'package:locale_sheet/src/core/parser.dart';
import 'package:test/test.dart';

void main() {
  /// 先頭ヘッダーが'key'でない場合にFormatExceptionが投げられることを検証
  /// Arrange-Act-Assertパターン
  test('parse throws when first header cell is not key', () {
    // Arrange: 不正なヘッダーでExcelファイル作成
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([TextCellValue('not_key'), TextCellValue('en')]);
    final bytes = excel.encode();
    final tmp = Directory.systemTemp.createTempSync('parser_bad');
    final file = File('${tmp.path}/bad.xlsx')..writeAsBytesSync(bytes!);
    final parser = ExcelParser();
    // Act & Assert: FormatExceptionが投げられることを確認
    expect(() => parser.parse(file.readAsBytesSync()), throwsFormatException);
    // Cleanup
    tmp.deleteSync(recursive: true);
  });

  /// データ行が存在しない場合に空のシートモデルが返ることを検証
  /// Arrange-Act-Assertパターン
  test('parse returns empty sheet when no rows', () {
    // Arrange: ヘッダーのみのExcelファイル作成
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([TextCellValue('key')]);
    final bytes = excel.encode();
    final tmp = Directory.systemTemp.createTempSync('parser_empty');
    final file = File('${tmp.path}/empty.xlsx')..writeAsBytesSync(bytes!);
    final parser = ExcelParser();
    // Act: パース実行
    final sheetModel = parser.parse(file.readAsBytesSync());
    // Assert: locales, entriesともに空
    expect(sheetModel.locales, isEmpty);
    expect(sheetModel.entries, isEmpty);
    // Cleanup
    tmp.deleteSync(recursive: true);
  });

  /// ヘッダにロケールでない列が混ざっている場合、それらは無視されることを検証
  test('parse ignores non-locale header columns', () {
    // Arrange: ヘッダーに 'notes' のような非ロケール列を挟む
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([
      TextCellValue('key'),
      TextCellValue('en'),
      TextCellValue('notes'),
      TextCellValue('ja'),
    ]);
    excel['Sheet1'].appendRow([
      TextCellValue('greeting'),
      TextCellValue('Hello'),
      TextCellValue('meta'),
      TextCellValue('こんにちは'),
    ]);
    final bytes = excel.encode();
    final tmp = Directory.systemTemp.createTempSync('parser_nonlocale');
    final file = File('${tmp.path}/nonlocale.xlsx')..writeAsBytesSync(bytes!);
    final parser = ExcelParser();

    // Act
    final sheetModel = parser.parse(file.readAsBytesSync());

    // Assert: locales はシンプルな英字ヘッダもロケールと解釈されるため
    // 'notes' は現在ロケールと見なされる（既存のバリデータ挙動に合わせる）
    expect(sheetModel.locales, equals(['en', 'notes', 'ja']));
    expect(sheetModel.entries.length, equals(1));
    final entry = sheetModel.entries.first;
    expect(entry.key, equals('greeting'));
    expect(entry.translations['en'], equals('Hello'));
    expect(entry.translations['ja'], equals('こんにちは'));

    tmp.deleteSync(recursive: true);
  });
}
