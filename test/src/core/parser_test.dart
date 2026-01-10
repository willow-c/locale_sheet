import 'dart:io';

import 'dart:typed_data';
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

  /// ヘッダに単純な英字単語の列が混ざっている場合、現状ではそれらがロケールとして扱われることを検証
  test('parse treats simple-word headers as locale tags', () {
    // Arrange: ヘッダーに 'notes' のような単純英字列を挟む
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

  test('parse reads a specified sheet by name', () {
    final excel = Excel.createExcel();
    // default sheet left untouched
    excel['MySheet'].appendRow([
      TextCellValue('key'),
      TextCellValue('en'),
    ]);
    excel['MySheet'].appendRow([
      TextCellValue('greeting'),
      TextCellValue('Hello'),
    ]);

    final bytes = excel.encode();
    final tmp = Directory.systemTemp.createTempSync('parser_sheetname');
    final file = File('${tmp.path}/sheetname.xlsx')..writeAsBytesSync(bytes!);
    final parser = ExcelParser();

    final sheetModel = parser.parse(
      file.readAsBytesSync(),
      sheetName: 'MySheet',
    );

    expect(sheetModel.locales, equals(['en']));
    expect(sheetModel.entries.length, equals(1));
    expect(sheetModel.entries.first.key, equals('greeting'));

    tmp.deleteSync(recursive: true);
  });

  test('parse throws when specified sheet name does not exist', () {
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([TextCellValue('key'), TextCellValue('en')]);
    final bytes = excel.encode();
    final tmp = Directory.systemTemp.createTempSync('parser_missing_sheet');
    final file = File('${tmp.path}/missing.xlsx')..writeAsBytesSync(bytes!);
    final parser = ExcelParser();

    expect(
      () => parser.parse(file.readAsBytesSync(), sheetName: 'NoSuch'),
      throwsA(isA<SheetNotFoundException>()),
    );

    tmp.deleteSync(recursive: true);
  });

  test('parse throws when workbook has no sheets', () {
    // Arrange: create an Excel and remove all sheets (empty workbook)
    // Simulate a decoder that cannot provide any sheets by throwing
    // SheetNotFoundException directly. This models the condition where
    // the workbook contains no usable sheets.
    final parser = ExcelParser(
      decoder: (_) {
        throw SheetNotFoundException('(first sheet)', <String>[]);
      },
    );

    // Act & Assert: parsing should propagate SheetNotFoundException
    expect(
      () => parser.parse(Uint8List.fromList([])),
      throwsA(isA<SheetNotFoundException>()),
    );
  });
}
