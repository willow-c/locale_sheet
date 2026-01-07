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
}
