import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:locale_sheet/src/core/xlsx_reader.dart';
import 'package:test/test.dart';

void main() {
  /// 重複した共有文字列があっても後続セルの参照位置を維持することを検証
  test('read preserves duplicate shared-string indices', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1">',
        '<c r="A1" t="s"><v>0</v></c>',
        '<c r="B1" t="s"><v>1</v></c>',
        '</row>',
        '<row r="2">',
        '<c r="A2" t="s"><v>3</v></c>',
        '<c r="B2" t="s"><v>4</v></c>',
        '</row>',
      ]),
      sharedStrings: [
        '<si><t>key</t></si>',
        '<si><t>en</t></si>',
        '<si><t>duplicate</t></si>',
        '<si><t>duplicate</t></si>',
        '<si><t>value after duplicate</t></si>',
      ],
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.sheetName, 'Sheet1');
    expect(sheet.rows[1][0], 'duplicate');
    expect(sheet.rows[1][1], 'value after duplicate');
  });

  /// ふりがな（rPh）は本文に含めず、装飾で分割された文字列は連結することを検証
  test('read joins rich-text runs and skips phonetic hints', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet(['<row r="1"><c r="A1" t="s"><v>0</v></c></row>']),
      sharedStrings: [
        [
          '<si><r><t>東京</t></r><r><t>都</t></r>',
          '<rPh sb="0" eb="2"><t>トウキョウ</t></rPh></si>',
        ].join(),
      ],
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0][0], '東京都');
  });

  /// インライン文字列のセルを読めることを検証
  test('read returns inline strings', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1"><c r="A1" t="inlineStr"><is><t>inline</t></is></c></row>',
      ]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0][0], 'inline');
  });

  /// 行・セルの `r` 属性は省略可能なので、出現順で位置を補うことを検証
  ///
  /// 捨ててしまうと仕様上有効なファイルが「空のシート」として読まれ、
  /// CLI が何も出力せずに成功扱いになる。
  test('read falls back to document order when cell references are absent', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row>',
        '<c t="inlineStr"><is><t>key</t></is></c>',
        '<c t="inlineStr"><is><t>en</t></is></c>',
        '</row>',
        '<row>',
        '<c t="inlineStr"><is><t>hello</t></is></c>',
        '<c t="inlineStr"><is><t>Hello</t></is></c>',
        '</row>',
      ]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows.length, 2);
    expect(sheet.rows[0], ['key', 'en']);
    expect(sheet.rows[1], ['hello', 'Hello']);
  });

  /// SpreadsheetML の上限を超える行参照は壊れた値として無視することを検証
  test('read ignores row references beyond the sheet limit', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1"><c r="A1" t="inlineStr"><is><t>ok</t></is></c></row>',
        '<row r="1048577">',
        '<c r="A1048577" t="inlineStr"><is><t>bogus</t></is></c>',
        '</row>',
      ]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert: 100万行分のリストを確保せず、有効な行だけを返す
    expect(sheet.rows.length, 1);
    expect(sheet.rows[0][0], 'ok');
  });

  /// 小文字の列参照（`b1`）も列番号として解釈できることを検証
  test('read accepts lower-case column references', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1"><c r="b1" t="inlineStr"><is><t>B</t></is></c></row>',
      ]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0], [null, 'B']);
  });

  /// 数式セルは計算せず式文字列を返し、`=` を補うことを検証
  test('read returns formula text with a leading equals sign', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1"><c r="A1"><f>SUM(B1:B2)</f><v>3</v></c></row>',
      ]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0][0], '=SUM(B1:B2)');
  });

  /// 共有数式の従属セルは式本体を持たないため、キャッシュ値を返すことを検証
  ///
  /// 式の有無だけで判断すると `=` だけの無意味な文字列になり、値が失われる。
  test('read falls back to the cached value for shared formula cells', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1">',
        '<c r="A1"><f t="shared" si="0" ref="A1:A2"/><v>7</v></c>',
        '</row>',
      ]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0][0], '7');
  });

  /// 真偽値セルが `true` / `false` になることを検証
  test('read converts boolean cells', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1">',
        '<c r="A1" t="b"><v>1</v></c>',
        '<c r="B1" t="b"><v>0</v></c>',
        '</row>',
      ]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0], ['true', 'false']);
  });

  /// 真偽値が `true` と綴られていても真として読むことを検証
  ///
  /// `1` 以外を偽とすると、失敗せずに**逆の値**を出すため下流で気付けない。
  test('read accepts a boolean cell written as true', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1">',
        '<c r="A1" t="b"><v>true</v></c>',
        '<c r="B1" t="b"><v>false</v></c>',
        '</row>',
      ]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0], ['true', 'false']);
  });

  /// インライン文字列でもふりがな（rPh）を本文に混ぜないことを検証
  ///
  /// `<is>` と `<si>` は同じ CT_Rst 型なので、経路によって値が変わってはいけない。
  test('read skips phonetic hints in inline strings', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1"><c r="A1" t="inlineStr"><is><t>東京</t>',
        '<rPh sb="0" eb="2"><t>トウキョウ</t></rPh></is></c></row>',
      ]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0][0], '東京');
  });

  /// 範囲外の書式索引を無視することを検証
  ///
  /// 下限を見ないと `RangeError`（`Error`）が漏れ、CLI の `on Exception` を
  /// 素通りして終了コードが入力エラー（65）ではなく 70 になる。
  test('read ignores an out-of-range style index', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1">',
        '<c r="A1" s="-1"><v>5</v></c>',
        '<c r="B1" s="9"><v>6</v></c>',
        '</row>',
      ]),
      styles: _styles(cellFormatIds: [14]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0], ['5', '6']);
  });

  /// 経過時間の書式が24時間で折り返さないことを検証
  ///
  /// `[h]` は「24時間で折り返さない」ための指定なので、30時間は `30:00:00`。
  test('read does not wrap elapsed time at 24 hours', () {
    // Arrange: 1.25 日 = 30 時間
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1">',
        '<c r="A1" s="0"><v>1.25</v></c>',
        '<c r="B1" s="1"><v>1.25</v></c>',
        '<c r="C1" s="2"><v>1.25</v></c>',
        '</row>',
      ]),
      styles: _styles(
        numberFormats: {164: '[h]:mm:ss'},
        // 46 は組み込みの `[h]:mm:ss`、21 は折り返す `h:mm:ss`
        cellFormatIds: [164, 46, 21],
      ),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0], ['30:00:00', '30:00:00', '06:00:00']);
  });

  /// リテラルの中に書いた `[h]` を経過時間の指定と誤認しないことを検証
  ///
  /// 判定は引用符・エスケープ・角括弧を剥がした後の文字列に対して行う。
  /// 生の書式コードを見ると、数値が経過時間として出力される。
  test('read ignores elapsed markers written inside a quoted literal', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1">',
        '<c r="A1" s="0"><v>1234.5</v></c>',
        '<c r="B1" s="1"><v>0.5</v></c>',
        '</row>',
      ]),
      styles: _styles(
        // 164 の `[h]` は表示する文字列、165 は経過時間の指定
        numberFormats: {164: '#,##0" [h] "', 165: '[mm]:ss'},
        cellFormatIds: [164, 165],
      ),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0], ['1234.5', '12:00:00']);
  });

  /// 色や通貨の角括弧指定を日付・時刻と誤認しないことを検証
  ///
  /// `[Red]` の `d`、`[$USD]` の `s` を書式指定と読むと、数値が日付や時刻に
  /// 化けて出力される。
  test('read keeps numbers formatted with colour or currency sections', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1">',
        '<c r="A1" s="0"><v>1234.5</v></c>',
        '<c r="B1" s="1"><v>1234.5</v></c>',
        '<c r="C1" s="2"><v>1234.5</v></c>',
        '</row>',
      ]),
      styles: _styles(
        numberFormats: {164: '[Red]#,##0.00', 165: r'[$USD]#,##0.00'},
        cellFormatIds: [0, 164, 165],
      ),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0], ['1234.5', '1234.5', '1234.5']);
  });

  /// ユーザー定義の日付・時刻書式を分類できることを検証
  test('read converts cells using custom date and time formats', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1">',
        '<c r="A1" s="0"><v>46231</v></c>',
        '<c r="B1" s="1"><v>0.5</v></c>',
        '</row>',
      ]),
      styles: _styles(
        numberFormats: {164: 'yyyy"年"m"月"d"日"', 165: '[h]:mm:ss'},
        cellFormatIds: [164, 165],
      ),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert: 経過時間の `[h]` は角括弧を除いても時刻として残る
    expect(sheet.rows[0][0], '2026-07-28T00:00:00.000Z');
    expect(sheet.rows[0][1], '12:00:00');
  });

  /// `m` が月と分のどちらなのかを、時・秒の有無で判断することを検証
  test('read reads a bare m as a month unless the format has time parts', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1">',
        '<c r="A1" s="0"><v>46231</v></c>',
        '<c r="B1" s="1"><v>0.5</v></c>',
        '</row>',
      ]),
      styles: _styles(
        numberFormats: {164: 'mmm', 165: 'h:mm'},
        cellFormatIds: [164, 165],
      ),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0][0], '2026-07-28T00:00:00.000Z');
    expect(sheet.rows[0][1], '12:00:00');
  });

  /// 東アジア向けの組み込み書式 ID も日付・時刻として扱うことを検証
  test('read classifies East Asian builtin number formats', () {
    // Arrange: 31 は `yyyy"年"m"月"d"日"`、32 は `h"時"mm"分"`
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1">',
        '<c r="A1" s="0"><v>46231</v></c>',
        '<c r="B1" s="1"><v>0.5</v></c>',
        '</row>',
      ]),
      styles: _styles(cellFormatIds: [31, 32]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0][0], '2026-07-28T00:00:00.000Z');
    expect(sheet.rows[0][1], '12:00:00');
  });

  /// 条件付き書式（dxfs）の `numFmt` がセル書式を汚染しないことを検証
  ///
  /// `dxfs` の ID はセル書式の ID と別空間なので、混ぜると無関係な書式で
  /// 数値が日付に化ける。
  test('read ignores number formats declared inside dxfs', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet(['<row r="1"><c r="A1" s="0"><v>46231</v></c></row>']),
      styles: [
        _styles(
          numberFormats: {164: '#,##0.00'},
          cellFormatIds: [164],
        ),
        '<dxfs count="1">',
        '<dxf><numFmt numFmtId="164" formatCode="yyyy/m/d"/></dxf>',
        '</dxfs>',
      ].join(),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0][0], '46231');
  });

  /// 1904 年方式のワークブックで日付の起点が変わることを検証
  test('read honours the 1904 date system', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet(['<row r="1"><c r="A1" s="0"><v>0</v></c></row>']),
      styles: _styles(cellFormatIds: [14]),
      workbookProperties: '<workbookPr date1904="1"/>',
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0][0], '1904-01-01T00:00:00.000Z');
  });

  /// `date1904` が `true` と綴られていても 1904 年方式と認識することを検証
  ///
  /// `xsd:boolean` は語形も正当。取りこぼすとシート内の全日付が 1462 日ずれる。
  test('read accepts date1904 written as true', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet(['<row r="1"><c r="A1" s="0"><v>0</v></c></row>']),
      styles: _styles(cellFormatIds: [14]),
      workbookProperties: '<workbookPr date1904="true"/>',
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows[0][0], '1904-01-01T00:00:00.000Z');
  });

  /// 名前空間の接頭辞で書かれた SpreadsheetML を読めることを検証
  ///
  /// `package:xml` の `findAllElements` は修飾名で照合するため、要素名を
  /// そのまま渡すと `<x:sheet>` 形式のファイルが1件もヒットしない。
  test('read parses SpreadsheetML written with namespace prefixes', () {
    // Arrange
    final bytes = _prefixedWorkbook();
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.sheetName, 'Sheet1');
    expect(sheet.rows[0], ['key', 'en']);
  });

  /// 上限ちょうどの空行があっても、その行数ぶんの領域を確保しないことを検証
  ///
  /// 行の長さは「実際にセルを持つ最終行」で決める。空行で伸ばすと、小さな
  /// ファイルで 100 万行を走査することになる。
  test('read sizes the sheet by the last row that has a value', () {
    // Arrange: セルの無い行と、値の無い `<c>` だけを持つ行の両方を末尾に置く。
    // 後者は Excel がデータより下の行に書式だけ付けたときに書き出す形。
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1"><c r="A1" t="inlineStr"><is><t>ok</t></is></c></row>',
        '<row r="1048575"/>',
        '<row r="1048576"><c r="A1048576"/></row>',
      ]),
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.rows.length, 1);
    expect(sheet.rows[0][0], 'ok');
  });

  /// 関係名前空間の接頭辞が `r` 以外でもシートを解決できることを検証
  ///
  /// 接頭辞の綴りはファイルが自由に決められるため、`r:id` の決め打ちは
  /// 「シートが見つからない」という無関係なエラーになる。
  test('read resolves sheets with a non-default relationship prefix', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet([
        '<row r="1"><c r="A1" t="inlineStr"><is><t>ok</t></is></c></row>',
      ]),
      relationshipPrefix: 'rel',
    );
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.sheetName, 'Sheet1');
    expect(sheet.rows[0][0], 'ok');
  });

  /// シートが1つも無いワークブックでは例外になることを検証（FR-05）
  test('read throws when the workbook has no sheets', () {
    // Arrange
    final bytes = _emptyWorkbook();
    const reader = XlsxReader();

    // Act & Assert
    expect(
      () => reader.read(bytes),
      throwsA(
        isA<XlsxSheetNotFoundException>()
            .having((e) => e.requestedSheet, 'requestedSheet', '(first sheet)')
            .having((e) => e.availableSheets, 'availableSheets', isEmpty),
      ),
    );
  });

  /// 存在しないシート名を指定した場合に、利用可能なシート名を添えて失敗することを検証
  test('read reports available sheets when the target is missing', () {
    // Arrange
    final bytes = _workbook(sheet: _sheet([]));
    const reader = XlsxReader();

    // Act & Assert
    expect(
      () => reader.read(bytes, sheetName: 'NoSuchSheet'),
      throwsA(
        isA<XlsxSheetNotFoundException>()
            .having((e) => e.requestedSheet, 'requestedSheet', 'NoSuchSheet')
            .having((e) => e.availableSheets, 'availableSheets', ['Sheet1']),
      ),
    );
  });

  /// シートが0件でもシート名の一覧は例外にしないことを検証
  test('readSheetNames returns an empty list without sheets', () {
    // Arrange
    final bytes = _emptyWorkbook();
    const reader = XlsxReader();

    // Act
    final names = reader.readSheetNames(bytes);

    // Assert
    expect(names, isEmpty);
  });

  /// シート名の一覧はワークシート本体を読まずに取得できることを検証
  test('readSheetNames does not read the worksheet body', () {
    // Arrange: ワークシートを不正な XML にしておく
    final bytes = _workbook(sheet: '<worksheet><broken>');
    const reader = XlsxReader();

    // Act
    final names = reader.readSheetNames(bytes);

    // Assert
    expect(names, ['Sheet1']);
  });

  /// XLSX ではないバイト列は FormatException になることを検証
  test('read throws a FormatException for a non-XLSX byte stream', () {
    // Arrange
    final bytes = Uint8List.fromList(List.filled(64, 7));
    const reader = XlsxReader();

    // Act & Assert
    expect(
      () => reader.read(bytes),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Invalid XLSX archive'),
        ),
      ),
    );
  });

  /// 必須のエントリが欠けている場合に、どのエントリかを示して失敗することを検証
  test('read throws when a required entry is missing', () {
    // Arrange: workbook.xml だけの ZIP
    final archive = Archive()
      ..addFile(
        _xmlFile(
          'xl/workbook.xml',
          [
            '<workbook xmlns="$_spreadsheetNamespace">',
            '<sheets/>',
            '</workbook>',
          ].join(),
        ),
      );
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    const reader = XlsxReader();

    // Act & Assert
    expect(
      () => reader.read(bytes),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('xl/_rels/workbook.xml.rels'),
        ),
      ),
    );
  });

  /// XML が壊れている場合に、どのエントリかを示して失敗することを検証
  test('read throws when an entry contains invalid XML', () {
    // Arrange
    final bytes = _workbook(sheet: '<worksheet><broken>');
    const reader = XlsxReader();

    // Act & Assert
    expect(
      () => reader.read(bytes),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('xl/worksheets/sheet1.xml'),
        ),
      ),
    );
  });

  /// 共有文字列の索引が範囲外の場合に失敗することを検証
  test('read throws when a shared-string index is out of range', () {
    // Arrange
    final bytes = _workbook(
      sheet: _sheet(['<row r="1"><c r="A1" t="s"><v>9</v></c></row>']),
      sharedStrings: ['<si><t>only</t></si>'],
    );
    const reader = XlsxReader();

    // Act & Assert
    expect(
      () => reader.read(bytes),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Invalid shared-string index'),
        ),
      ),
    );
  });
}

const _spreadsheetNamespace =
    'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _officeRelationshipsNamespace =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _packageRelationshipsNamespace =
    'http://schemas.openxmlformats.org/package/2006/relationships';

/// `sheetData` の中身から最小のワークシート XML を組み立てます。
String _sheet(List<String> rows) => [
  '<worksheet xmlns="$_spreadsheetNamespace"><sheetData>',
  ...rows,
  '</sheetData></worksheet>',
].join();

/// `styleSheet` の中身（`numFmts` と `cellXfs`）を組み立てます。
String _styles({
  required List<int> cellFormatIds,
  Map<int, String> numberFormats = const {},
}) {
  final numFmts = numberFormats.entries
      .map(
        (entry) => [
          '<numFmt numFmtId="${entry.key}"',
          ' formatCode="${_escapeAttribute(entry.value)}"/>',
        ].join(),
      )
      .join();
  final xfs = cellFormatIds.map((id) => '<xf numFmtId="$id"/>').join();
  return [
    if (numFmts.isNotEmpty) '<numFmts>$numFmts</numFmts>',
    '<cellXfs count="${cellFormatIds.length}">$xfs</cellXfs>',
  ].join();
}

/// 書式コードは `"` を含むため、属性値として書ける形に直します。
String _escapeAttribute(String value) =>
    value.replaceAll('&', '&amp;').replaceAll('"', '&quot;');

/// シートを1つだけ持つ最小の XLSX を組み立てます。
Uint8List _workbook({
  required String sheet,
  List<String> sharedStrings = const [],
  String? styles,
  String? workbookProperties,
  String relationshipPrefix = 'r',
}) {
  final archive = Archive()
    ..addFile(
      _xmlFile(
        'xl/workbook.xml',
        [
          '<workbook xmlns="$_spreadsheetNamespace"',
          ' xmlns:$relationshipPrefix="$_officeRelationshipsNamespace">',
          workbookProperties ?? '',
          '<sheets>',
          '<sheet name="Sheet1" sheetId="1" $relationshipPrefix:id="rId1"/>',
          '</sheets></workbook>',
        ].join(),
      ),
    )
    ..addFile(
      _xmlFile(
        'xl/_rels/workbook.xml.rels',
        [
          '<Relationships xmlns="$_packageRelationshipsNamespace">',
          '<Relationship Id="rId1" Target="worksheets/sheet1.xml"',
          ' Type="$_officeRelationshipsNamespace/worksheet"/>',
          '</Relationships>',
        ].join(),
      ),
    )
    ..addFile(_xmlFile('xl/worksheets/sheet1.xml', sheet));
  if (sharedStrings.isNotEmpty) {
    archive.addFile(
      _xmlFile(
        'xl/sharedStrings.xml',
        [
          '<sst xmlns="$_spreadsheetNamespace">',
          ...sharedStrings,
          '</sst>',
        ].join(),
      ),
    );
  }
  if (styles != null) {
    archive.addFile(
      _xmlFile(
        'xl/styles.xml',
        [
          '<styleSheet xmlns="$_spreadsheetNamespace">',
          styles,
          '</styleSheet>',
        ].join(),
      ),
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// すべての部品を名前空間の接頭辞付きで書いた XLSX を組み立てます。
///
/// 既定名前空間ではなく `<x:sheet>` 形式で書かれたファイルを模します。
Uint8List _prefixedWorkbook() {
  final archive = Archive()
    ..addFile(
      _xmlFile(
        'xl/workbook.xml',
        [
          '<x:workbook xmlns:x="$_spreadsheetNamespace"',
          ' xmlns:rel="$_officeRelationshipsNamespace">',
          '<x:sheets>',
          '<x:sheet name="Sheet1" sheetId="1" rel:id="rId1"/>',
          '</x:sheets></x:workbook>',
        ].join(),
      ),
    )
    ..addFile(
      _xmlFile(
        'xl/_rels/workbook.xml.rels',
        [
          '<pkg:Relationships xmlns:pkg="$_packageRelationshipsNamespace">',
          '<pkg:Relationship Id="rId1" Target="worksheets/sheet1.xml"',
          ' Type="$_officeRelationshipsNamespace/worksheet"/>',
          '</pkg:Relationships>',
        ].join(),
      ),
    )
    ..addFile(
      _xmlFile(
        'xl/worksheets/sheet1.xml',
        [
          '<x:worksheet xmlns:x="$_spreadsheetNamespace"><x:sheetData>',
          '<x:row r="1">',
          '<x:c r="A1" t="s"><x:v>0</x:v></x:c>',
          '<x:c r="B1" t="inlineStr"><x:is><x:t>en</x:t></x:is></x:c>',
          '</x:row>',
          '</x:sheetData></x:worksheet>',
        ].join(),
      ),
    )
    ..addFile(
      _xmlFile(
        'xl/sharedStrings.xml',
        [
          '<x:sst xmlns:x="$_spreadsheetNamespace">',
          '<x:si><x:t>key</x:t></x:si>',
          '</x:sst>',
        ].join(),
      ),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// シートを1つも持たない最小の XLSX を組み立てます。
Uint8List _emptyWorkbook() {
  final archive = Archive()
    ..addFile(
      _xmlFile(
        'xl/workbook.xml',
        [
          '<workbook xmlns="$_spreadsheetNamespace">',
          '<sheets/>',
          '</workbook>',
        ].join(),
      ),
    )
    ..addFile(
      _xmlFile(
        'xl/_rels/workbook.xml.rels',
        '<Relationships xmlns="$_packageRelationshipsNamespace"/>',
      ),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

ArchiveFile _xmlFile(String path, String contents) {
  final bytes = utf8.encode(contents);
  return ArchiveFile(path, bytes.length, bytes);
}
