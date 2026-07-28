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

  /// localesを明示指定した場合、指定した列だけがロケールとして扱われ、
  /// ロケールタグらしい他の列（memo等）が無視されることを検証
  /// Arrange-Act-Assertパターン
  test('parse uses only the requested locales when locales is given', () {
    // Arrange: memo は isValidLocaleTag では妥当と判定されてしまう列名
    final excel = Excel.createExcel();
    excel['Sheet1']
      ..appendRow([
        TextCellValue('key'),
        TextCellValue('en'),
        TextCellValue('ja'),
        TextCellValue('memo'),
      ])
      ..appendRow([
        TextCellValue('hello'),
        TextCellValue('Hello'),
        TextCellValue('こんにちは'),
        TextCellValue('a note'),
      ]);
    final parser = ExcelParser(decoder: (_) => excel);

    // Act
    final sheet = parser.parse(Uint8List(0), locales: ['en', 'ja']);

    // Assert: memo はロケールから外れ、無視した列として記録される
    expect(sheet.locales, ['en', 'ja']);
    expect(sheet.ignoredHeaders, ['memo']);
    expect(sheet.entries.single.translations.keys, ['en', 'ja']);
  });

  /// localesの照合が大文字小文字と区切り文字の違いを吸収することを検証
  /// Arrange-Act-Assertパターン
  test('parse matches requested locales ignoring case and separators', () {
    // Arrange: ヘッダは zh-Hant-HK、指定は zh_hant_hk
    final excel = Excel.createExcel();
    excel['Sheet1']
      ..appendRow([TextCellValue('key'), TextCellValue('zh-Hant-HK')])
      ..appendRow([TextCellValue('hello'), TextCellValue('你好')]);
    final parser = ExcelParser(decoder: (_) => excel);

    // Act
    final sheet = parser.parse(Uint8List(0), locales: ['zh_hant_hk']);

    // Assert: ロケール名はヘッダの表記がそのまま保持される
    expect(sheet.locales, ['zh-Hant-HK']);
    expect(sheet.ignoredHeaders, isEmpty);
  });

  /// 指定したロケール列が1行目に存在しない場合にFormatExceptionとなることを検証
  /// Arrange-Act-Assertパターン
  test('parse throws when a requested locale column is missing', () {
    // Arrange
    final excel = Excel.createExcel();
    excel['Sheet1']
      ..appendRow([TextCellValue('key'), TextCellValue('en')])
      ..appendRow([TextCellValue('hello'), TextCellValue('Hello')]);
    final parser = ExcelParser(decoder: (_) => excel);

    // Act & Assert: 綴り間違いを黙って落とさない
    expect(
      () => parser.parse(Uint8List(0), locales: ['en', 'fr']),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('fr'),
        ),
      ),
    );
  });

  /// localesを指定しない場合は従来どおり自動判定され、
  /// 判定から外れた列がignoredHeadersに記録されることを検証
  /// Arrange-Act-Assertパターン
  test('parse records ignored headers when locales is not given', () {
    // Arrange: description は9文字以上、備考は非英字なので自動判定から外れる
    final excel = Excel.createExcel();
    excel['Sheet1']
      ..appendRow([
        TextCellValue('key'),
        TextCellValue('en'),
        TextCellValue('description'),
        TextCellValue('備考'),
      ])
      ..appendRow([
        TextCellValue('hello'),
        TextCellValue('Hello'),
        TextCellValue('desc'),
        TextCellValue('note'),
      ]);
    final parser = ExcelParser(decoder: (_) => excel);

    // Act
    final sheet = parser.parse(Uint8List(0));

    // Assert
    expect(sheet.locales, ['en']);
    expect(sheet.ignoredHeaders, ['description', '備考']);
  });

  /// 区切り文字だけが違うロケール列がエラーになることを検証
  /// Arrange-Act-Assertパターン
  test('parse throws when locale columns differ only by separator', () {
    // Arrange: zh-TW と zh_TW は同じロケールを指す
    final excel = Excel.createExcel();
    excel['Sheet1']
      ..appendRow([
        TextCellValue('key'),
        TextCellValue('zh-TW'),
        TextCellValue('zh_TW'),
      ])
      ..appendRow([
        TextCellValue('hello'),
        TextCellValue('你好'),
        TextCellValue('您好'),
      ]);
    final parser = ExcelParser(decoder: (_) => excel);

    // Act & Assert: 衝突した両方のヘッダ名がメッセージに含まれる
    expect(
      () => parser.parse(Uint8List(0)),
      throwsA(
        isA<FormatException>()
            .having((e) => e.message, 'message', contains('zh-TW'))
            .having((e) => e.message, 'message', contains('zh_TW')),
      ),
    );
  });

  /// 大文字小文字だけが違うロケール列がエラーになることを検証
  /// Arrange-Act-Assertパターン
  test('parse throws when locale columns differ only by letter case', () {
    // Arrange: BCP 47 では大文字小文字は有意でないため en と EN は同じ
    final excel = Excel.createExcel();
    excel['Sheet1']
      ..appendRow([
        TextCellValue('key'),
        TextCellValue('en'),
        TextCellValue('EN'),
      ])
      ..appendRow([
        TextCellValue('hello'),
        TextCellValue('Hello'),
        TextCellValue('HELLO'),
      ]);
    final parser = ExcelParser(decoder: (_) => excel);

    // Act & Assert
    expect(
      () => parser.parse(Uint8List(0)),
      throwsA(isA<FormatException>()),
    );
  });

  /// ヘッダ行すら無い（行数0の）シートでも例外にせず
  /// 空のシートモデルを返すことを検証
  /// Arrange-Act-Assertパターン
  test('parse returns an empty sheet when the sheet has no rows at all', () {
    // Arrange: 一度も書き込んでいないシートは行数0になる
    final excel = Excel.createExcel();
    expect(excel.tables[excel.getDefaultSheet()]!.rows, isEmpty);
    final parser = ExcelParser(decoder: (_) => excel);

    // Act
    final sheet = parser.parse(Uint8List(0));

    // Assert: ヘッダ検証に到達せず、空の結果が返る
    expect(sheet.locales, isEmpty);
    expect(sheet.entries, isEmpty);
  });

  test('getSheetNames returns available sheet names via decoder', () {
    final excel = Excel.createExcel();
    excel['Alpha'].appendRow([TextCellValue('key')]);
    final parser = ExcelParser(decoder: (_) => excel);

    final names = parser.getSheetNames(Uint8List.fromList([]));
    expect(names, contains('Alpha'));
  });

  test('SheetNotFoundException toString contains available sheets', () {
    // Arrange
    final excel = Excel.createExcel();
    final _ = excel['A'];
    final parser = ExcelParser(decoder: (_) => excel);

    // Act & Assert
    try {
      // Act: attempt to parse a non-existent sheet
      parser.parse(Uint8List(0), sheetName: 'NoSuchSheet');
      fail('Expected SheetNotFoundException');
    } on SheetNotFoundException catch (e) {
      // Assert: message contains requested and available sheet names
      expect(e.toString(), contains('NoSuchSheet'));
      expect(e.toString(), contains('A'));
    }
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

  test('parse is case-insensitive for descriptionHeader matching', () {
    // Arrange: header contains 'description' lowercase,
    // caller passes 'Description'
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
    final tmp = Directory.systemTemp.createTempSync('parser_desc_case');
    final file = File('${tmp.path}/desc_case.xlsx')..writeAsBytesSync(bytes);
    final parser = ExcelParser();

    try {
      // Act: pass descriptionHeader with different casing
      final sheet = parser.parse(
        file.readAsBytesSync(),
        descriptionHeader: 'Description',
      );

      // Assert
      expect(sheet.locales, equals(['en', 'ja']));
      expect(sheet.entries.length, equals(1));
      final e = sheet.entries.first;
      expect(e.key, equals('greeting'));
      expect(e.description, equals('A friendly greeting'));
    } finally {
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

  test('parse throws when descriptionHeader is key (invalid)', () {
    // Arrange
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([TextCellValue('key'), TextCellValue('en')]);
    excel['Sheet1'].appendRow([
      TextCellValue('greeting'),
      TextCellValue('Hello'),
    ]);

    final bytes = excel.encode()!;
    final tmp = Directory.systemTemp.createTempSync('parser_desc_key');
    final file = File('${tmp.path}/desc_key.xlsx')..writeAsBytesSync(bytes);
    final parser = ExcelParser();

    try {
      // Act & Assert:
      // specifying 'key' (case-insensitive) as description header is invalid
      expect(
        () => parser.parse(
          file.readAsBytesSync(),
          descriptionHeader: 'key',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            "Description header cannot be 'key'",
          ),
        ),
      );
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  test('parse throws when descriptionHeader conflicts with locale tag', () {
    // Arrange: header contains a locale 'fr' and user mistakenly sets
    // descriptionHeader to 'fr'. This should be rejected.
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([
      TextCellValue('key'),
      TextCellValue('fr'),
      TextCellValue('en'),
    ]);
    excel['Sheet1'].appendRow([
      TextCellValue('greeting'),
      TextCellValue('Bonjour'),
      TextCellValue('Hello'),
    ]);

    final bytes = excel.encode()!;
    final tmp = Directory.systemTemp.createTempSync('parser_desc_conflict');
    final file = File('${tmp.path}/desc_conflict.xlsx')
      ..writeAsBytesSync(bytes);
    final parser = ExcelParser();

    try {
      expect(
        () => parser.parse(
          file.readAsBytesSync(),
          descriptionHeader: 'fr',
        ),
        throwsFormatException,
      );
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  test('parse treats empty or whitespace description cells as null', () {
    // Arrange
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow([
      TextCellValue('key'),
      TextCellValue('en'),
      TextCellValue('description'),
      TextCellValue('ja'),
    ]);
    excel['Sheet1'].appendRow([
      TextCellValue('g1'),
      TextCellValue('Hello'),
      TextCellValue(''),
      TextCellValue('こんにちは'),
    ]);
    excel['Sheet1'].appendRow([
      TextCellValue('g2'),
      TextCellValue('Hi'),
      TextCellValue('   '),
      TextCellValue('やあ'),
    ]);
    excel['Sheet1'].appendRow([
      TextCellValue('g3'),
      TextCellValue('Hey'),
      TextCellValue('A desc'),
      TextCellValue('やっほ'),
    ]);

    final bytes = excel.encode()!;
    final tmp = Directory.systemTemp.createTempSync('parser_desc_empty');
    final path = '${tmp.path}/desc_empty.xlsx';
    File(path).writeAsBytesSync(bytes);

    final parser = ExcelParser();

    try {
      // Act
      final sheet = parser.parse(
        File(path).readAsBytesSync(),
        descriptionHeader: 'description',
      );

      // Assert: empty or whitespace-only descriptions become null
      final byKey = {
        for (final e in sheet.entries) e.key: e,
      };
      expect(byKey['g1']!.description, isNull);
      expect(byKey['g2']!.description, isNull);
      expect(byKey['g3']!.description, equals('A desc'));
    } finally {
      // Cleanup
      tmp.deleteSync(recursive: true);
    }
  });
}
