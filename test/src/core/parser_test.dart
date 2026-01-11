import 'dart:io';

import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:locale_sheet/src/core/parser.dart';
import 'package:test/test.dart';

void main() {
  /// 先頭ヘッダーが'key'でない場合にFormatExceptionが投げられることを検証
  test('parse throws when first header cell is not key', () {
    // Arrange
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([TextCellValue('not_key'), TextCellValue('en')]);
    final bytes = excel.encode();
    final tmp = Directory.systemTemp.createTempSync('parser_bad');
    final file = File('${tmp.path}/bad.xlsx')..writeAsBytesSync(bytes!);
    final parser = ExcelParser();

    try {
      // Act & Assert
      expect(() => parser.parse(file.readAsBytesSync()), throwsFormatException);
    } finally {
      // Cleanup
      tmp.deleteSync(recursive: true);
    }
  });

  /// データ行が存在しない場合に空のシートモデルが返ることを検証
  /// Arrange-Act-Assertパターン
  test('parse returns empty sheet when no rows', () {
    // Arrange
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([TextCellValue('key')]);
    final bytes = excel.encode();
    final tmp = Directory.systemTemp.createTempSync('parser_empty');
    final file = File('${tmp.path}/empty.xlsx')..writeAsBytesSync(bytes!);
    final parser = ExcelParser();

    try {
      // Act
      final sheetModel = parser.parse(file.readAsBytesSync());

      // Assert
      expect(sheetModel.locales, isEmpty);
      expect(sheetModel.entries, isEmpty);
    } finally {
      // Cleanup
      tmp.deleteSync(recursive: true);
    }
  });

  /// ヘッダに単純な英字単語の列が混ざっている場合、現状ではそれらがロケールとして扱われることを検証
  test('parse treats simple-word headers as locale tags', () {
    // Arrange
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

    try {
      // Act
      final sheetModel = parser.parse(file.readAsBytesSync());

      // Assert
      expect(sheetModel.locales, equals(['en', 'notes', 'ja']));
      expect(sheetModel.entries.length, equals(1));
      final entry = sheetModel.entries.first;
      expect(entry.key, equals('greeting'));
      expect(entry.translations['en'], equals('Hello'));
      expect(entry.translations['ja'], equals('こんにちは'));
    } finally {
      // Cleanup
      tmp.deleteSync(recursive: true);
    }
  });

  test('parse reads a specified sheet by name', () {
    // Arrange
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

    try {
      // Act
      final sheetModel = parser.parse(
        file.readAsBytesSync(),
        sheetName: 'MySheet',
      );

      // Assert
      expect(sheetModel.locales, equals(['en']));
      expect(sheetModel.entries.length, equals(1));
      expect(sheetModel.entries.first.key, equals('greeting'));
    } finally {
      // Cleanup
      tmp.deleteSync(recursive: true);
    }
  });

  test('parse throws when specified sheet name does not exist', () {
    // Arrange
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([TextCellValue('key'), TextCellValue('en')]);
    final bytes = excel.encode();
    final tmp = Directory.systemTemp.createTempSync('parser_missing_sheet');
    final file = File('${tmp.path}/missing.xlsx')..writeAsBytesSync(bytes!);
    final parser = ExcelParser();

    try {
      // Act & Assert
      expect(
        () => parser.parse(file.readAsBytesSync(), sheetName: 'NoSuch'),
        throwsA(isA<SheetNotFoundException>()),
      );
    } finally {
      // Cleanup
      tmp.deleteSync(recursive: true);
    }
  });

  test('parse throws when workbook has no sheets', () {
    // Arrange
    final parser = ExcelParser(
      decoder: (_) {
        throw SheetNotFoundException('(first sheet)', <String>[]);
      },
    );

    // Act & Assert
    expect(
      () => parser.parse(Uint8List.fromList([])),
      throwsA(isA<SheetNotFoundException>()),
    );
  });

  test('getSheetNames returns available sheet names via decoder', () {
    final excel = Excel.createExcel();
    excel['Alpha'].appendRow([TextCellValue('key')]);
    final parser = ExcelParser(decoder: (_) => excel);

    final names = parser.getSheetNames(Uint8List.fromList([]));
    expect(names, contains('Alpha'));
  });

  test('parse skips empty header columns and detects locales correctly', () {
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([
      TextCellValue('key'),
      TextCellValue(''),
      TextCellValue('en'),
    ]);
    excel['Sheet1'].appendRow([
      TextCellValue('hello'),
      TextCellValue(''),
      TextCellValue('Hi'),
    ]);

    final bytes = excel.encode()!;
    final tmp = Directory.systemTemp.createTempSync('parser_empty_header_col');
    final file = File('${tmp.path}/ehc.xlsx')..writeAsBytesSync(bytes);
    final parser = ExcelParser();

    try {
      final sheet = parser.parse(file.readAsBytesSync());
      expect(sheet.locales, equals(['en']));
      expect(sheet.entries.length, equals(1));
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  test('parse skips rows with empty keys and empty rows', () {
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([TextCellValue('key'), TextCellValue('en')]);
    // empty row
    excel['Sheet1'].appendRow([]);
    // row with empty key
    excel['Sheet1'].appendRow([TextCellValue(''), TextCellValue('No')]);
    // valid row
    excel['Sheet1'].appendRow([TextCellValue('g'), TextCellValue('Yes')]);

    final bytes = excel.encode()!;
    final tmp = Directory.systemTemp.createTempSync('parser_row_skip');
    final file = File('${tmp.path}/rows.xlsx')..writeAsBytesSync(bytes);
    final parser = ExcelParser();

    try {
      final sheet = parser.parse(file.readAsBytesSync());
      expect(sheet.entries.length, equals(1));
      expect(sheet.entries.first.key, equals('g'));
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  test('parse reads description column when descriptionHeader provided', () {
    // Arrange
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([
      TextCellValue('key'),
      TextCellValue('en'),
      TextCellValue('description'),
      TextCellValue('ja'),
    ]);
    excel['Sheet1'].appendRow([
      TextCellValue('greeting'),
      TextCellValue('Hello'),
      TextCellValue('A friendly greeting'),
      TextCellValue('こんにちは'),
    ]);

    final bytes = excel.encode()!;
    final tmp = Directory.systemTemp.createTempSync('parser_desc');
    final file = File('${tmp.path}/desc.xlsx')..writeAsBytesSync(bytes);

    final parser = ExcelParser();

    try {
      // Act
      final sheet = parser.parse(
        file.readAsBytesSync(),
        descriptionHeader: 'description',
      );

      // Assert
      expect(sheet.locales, equals(['en', 'ja']));
      expect(sheet.entries.length, equals(1));
      final e = sheet.entries.first;
      expect(e.key, equals('greeting'));
      expect(e.description, equals('A friendly greeting'));
    } finally {
      // Cleanup
      tmp.deleteSync(recursive: true);
    }
  });

  test('parse throws when provided descriptionHeader not found', () {
    // Arrange
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([TextCellValue('key'), TextCellValue('en')]);
    excel['Sheet1'].appendRow([
      TextCellValue('greeting'),
      TextCellValue('Hello'),
    ]);

    final bytes = excel.encode()!;
    final tmp = Directory.systemTemp.createTempSync('parser_desc_missing');
    final file = File('${tmp.path}/desc_missing.xlsx')..writeAsBytesSync(bytes);

    final parser = ExcelParser();

    try {
      // Act & Assert
      expect(
        () => parser.parse(
          file.readAsBytesSync(),
          descriptionHeader: 'description',
        ),
        throwsFormatException,
      );
    } finally {
      // Cleanup
      tmp.deleteSync(recursive: true);
    }
  });
}
