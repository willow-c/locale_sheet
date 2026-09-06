import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// XLSX から読み取った対象シートとワークブック情報。
class XlsxSheetData {
  /// Creates sheet data.
  const XlsxSheetData({
    required this.sheetName,
    required this.availableSheets,
    required this.rows,
  });

  /// 実際に読み取ったシート名。
  final String sheetName;

  /// ワークブックに含まれるシート名。
  final List<String> availableSheets;

  /// 行・列番号に対応するセル文字列。
  final List<List<String?>> rows;
}

/// ローカライズ表に必要なセル値だけを XLSX から読み取ります。
class XlsxReader {
  /// Creates an XLSX reader.
  const XlsxReader();

  /// 名前空間を問わずローカル名で照合するための指定。
  ///
  /// SpreadsheetML は既定名前空間でも接頭辞付き（`<x:sheet>` / `r:id`）でも
  /// 書ける。`package:xml` の `findAllElements('sheet')` は**修飾名**で照合
  /// するため、接頭辞付きのファイルが1件もヒットしない。名前空間 URI を
  /// 指定する形にすると、今度は `xmlns` を書かない最小ファイル
  /// （`namespaceUri` が null）を落とす。どちらも読めるようにローカル名で
  /// 照合する。
  static const _anyNamespace = '*';

  /// SpreadsheetML の上限。これを超える参照は壊れたファイルとみなす。
  ///
  /// `r="1048577"` のような値をそのまま信じると、行リストの確保だけで
  /// メモリを使い切る。
  static const _maxRows = 1048576;
  static const _maxColumns = 16384;

  /// Reads one worksheet from [bytes].
  XlsxSheetData read(Uint8List bytes, {String? sheetName}) {
    final archive = _decodeArchive(bytes);
    final workbook = _readXml(archive, 'xl/workbook.xml');
    final sheets = _readSheetIndex(archive, workbook);
    final availableSheets = sheets.map((sheet) => sheet.name).toList();
    if (sheets.isEmpty) {
      throw XlsxSheetNotFoundException(
        sheetName ?? '(first sheet)',
        availableSheets,
      );
    }

    final selectedName = sheetName ?? sheets.first.name;
    final selected = sheets
        .where((sheet) => sheet.name == selectedName)
        .firstOrNull;
    if (selected == null) {
      throw XlsxSheetNotFoundException(selectedName, availableSheets);
    }

    final sharedStrings = _readSharedStrings(archive);
    final cellFormats = _readCellFormats(archive);
    final uses1904DateSystem = workbook
        .findAllElements('workbookPr', namespace: _anyNamespace)
        .any((element) => _isTrue(element.getAttribute('date1904')));
    final worksheet = _readXml(archive, selected.path);

    return XlsxSheetData(
      sheetName: selected.name,
      availableSheets: availableSheets,
      rows: _readRows(
        worksheet,
        sharedStrings,
        cellFormats,
        uses1904DateSystem,
      ),
    );
  }

  /// Reads only the sheet names contained in [bytes].
  ///
  /// ワークシート本体は読まない。シートが1つも無いワークブックは空リストを
  /// 返す（[read] と違って例外にしない）。呼び出し側が「一覧を得る」目的で
  /// 使うため、空である事実をそのまま返すほうが扱いやすい。
  List<String> readSheetNames(Uint8List bytes) {
    final archive = _decodeArchive(bytes);
    final sheets = _readSheetIndex(
      archive,
      _readXml(archive, 'xl/workbook.xml'),
    );
    return sheets.map((sheet) => sheet.name).toList();
  }

  List<({String name, String path})> _readSheetIndex(
    Archive archive,
    XmlDocument workbook,
  ) {
    final relationships = _readXml(archive, 'xl/_rels/workbook.xml.rels');

    final targetsById = <String, String>{};
    for (final relationship in relationships.findAllElements(
      'Relationship',
      namespace: _anyNamespace,
    )) {
      final id = relationship.getAttribute('Id');
      final target = relationship.getAttribute('Target');
      if (id != null && target != null) {
        targetsById[id] = _resolveWorkbookTarget(target);
      }
    }

    final sheets = <({String name, String path})>[];
    for (final sheet in workbook.findAllElements(
      'sheet',
      namespace: _anyNamespace,
    )) {
      final name = sheet.getAttribute('name');
      final relationshipId = sheet.getAttribute(
        'id',
        namespace: _anyNamespace,
      );
      final path = targetsById[relationshipId];
      if (name != null && path != null) {
        sheets.add((name: name, path: path));
      }
    }
    return sheets;
  }

  Archive _decodeArchive(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } on Exception catch (error) {
      // 壊れた ZIP・別形式のファイルは `ArchiveException`（`Exception`）で
      // 落ちる。`Error` は握らない（`avoid_catching_errors`）。
      throw FormatException('Invalid XLSX archive: $error');
    }
  }

  XmlDocument _readXml(Archive archive, String path) {
    final document = _readXmlOrNull(archive, path);
    if (document == null) {
      throw FormatException('Required XLSX entry is missing: $path');
    }
    return document;
  }

  XmlDocument? _readXmlOrNull(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    try {
      return XmlDocument.parse(utf8.decode(file.content as List<int>));
    } on Exception catch (error) {
      throw FormatException('Invalid XML in XLSX entry "$path": $error');
    }
  }

  List<String> _readSharedStrings(Archive archive) {
    final document = _readXmlOrNull(archive, 'xl/sharedStrings.xml');
    if (document == null) return const [];

    return document
        .findAllElements('si', namespace: _anyNamespace)
        .map(_richText)
        .toList(growable: false);
  }

  /// `CT_Rst`（`<si>` と `<is>`）から本文を取り出します。
  ///
  /// 装飾で分割された `<r>` は連結し、ふりがな（`<rPh>`）は本文ではないので
  /// 除く。共有文字列とインライン文字列は同じ型なので、経路によって値が
  /// 変わらないよう同じ処理を通す。
  String _richText(XmlElement text) => text
      .findAllElements('t', namespace: _anyNamespace)
      .where((item) => item.parentElement?.localName != 'rPh')
      .map((item) => item.innerText)
      .join();

  /// `xsd:boolean` の字句表現を判定します（`1` と `true` のどちらも真）。
  bool _isTrue(String? value) => value == '1' || value?.toLowerCase() == 'true';

  List<_CellFormat> _readCellFormats(Archive archive) {
    final document = _readXmlOrNull(archive, 'xl/styles.xml');
    if (document == null) return const [];

    // `numFmt` は条件付き書式（`dxfs`）の中にも現れる。ID の意味が別物なので
    // 文書全体を走査すると、セル書式の定義を無関係な書式で上書きしてしまう。
    final customFormats = <int, String>{};
    final numberFormats = document
        .findAllElements('numFmts', namespace: _anyNamespace)
        .firstOrNull;
    final numberFormatElements =
        numberFormats?.findElements('numFmt', namespace: _anyNamespace) ??
        const <XmlElement>[];
    for (final format in numberFormatElements) {
      final id = int.tryParse(format.getAttribute('numFmtId') ?? '');
      final code = format.getAttribute('formatCode');
      if (id != null && code != null) customFormats[id] = code;
    }

    final cellFormats = document
        .findAllElements('cellXfs', namespace: _anyNamespace)
        .firstOrNull;
    if (cellFormats == null) return const [];
    return cellFormats
        .findElements('xf', namespace: _anyNamespace)
        .map((format) {
          final id = int.tryParse(format.getAttribute('numFmtId') ?? '') ?? 0;
          return _classifyFormat(id, customFormats[id]);
        })
        .toList(growable: false);
  }

  /// 組み込みの日付書式 ID。
  ///
  /// 14〜17 と 22 に加え、27〜31 / 36 / 50〜54 / 57 / 58 は東アジア向けの
  /// 日付書式（`yyyy"年"m"月"d"日"` など）に割り当てられている。日本語・
  /// 中国語のシートでは実際に使われるため、生のシリアル値を出さないよう
  /// 対象に含める。
  static const _builtinDateFormatIds = {
    14, 15, 16, 17, 22, //
    27, 28, 29, 30, 31, 36, //
    50, 51, 52, 53, 54, 57, 58,
  };

  /// 組み込みの時刻書式 ID。32〜35 / 55 / 56 は東アジア向け（`h"時"mm"分"`）。
  static const _builtinTimeFormatIds = {
    18, 19, 20, 21, 45, 47, //
    32, 33, 34, 35, 55, 56,
  };

  /// 組み込みの経過時間書式 ID。46 は `[h]:mm:ss`。
  static const _builtinElapsedFormatIds = {46};

  /// 角括弧セクションのうち、経過時間（`[h]` / `[mm]` / `[ss]`）以外を除く。
  ///
  /// `[Red]` や `[$USD]` を残したまま `d` / `y` / `s` を探すと、色や通貨の
  /// 綴りが日付・時刻の指定と誤認される。
  static final _nonElapsedBracket = RegExp(
    r'\[(?![hms]+\])[^\]]*\]',
    caseSensitive: false,
  );

  /// 経過時間の角括弧指定（`[h]` / `[mm]` / `[ss]`）。
  static final _elapsedBracket = RegExp(r'\[[hms]+\]', caseSensitive: false);

  _CellFormat _classifyFormat(int id, String? customCode) {
    if (_builtinElapsedFormatIds.contains(id)) return _CellFormat.elapsed;
    if (_builtinTimeFormatIds.contains(id)) return _CellFormat.time;
    if (_builtinDateFormatIds.contains(id)) return _CellFormat.dateTime;
    if (customCode == null) return _CellFormat.other;

    // 判定はすべて「引用符・エスケープ・角括弧セクションを剥がした後」の
    // 文字列に対して行う。生のコードを見ると、`#,##0" [h] "` のように
    // リテラルへ書いた `[h]` を書式指定として拾ってしまう。
    final code = customCode
        // エスケープを先に外す。`\"` を残すと文字列リテラルの判定がずれる。
        .replaceAll(RegExp(r'\\.'), '')
        .replaceAll(RegExp('"[^"]*"'), '')
        .replaceAll(_nonElapsedBracket, '')
        .toLowerCase();
    final hasTime = code.contains('h') || code.contains('s');
    // `m` は月と分を兼ねる。時・秒が無ければ月とみなす（`mmm` など）。
    final hasDate =
        code.contains('d') ||
        code.contains('y') ||
        (!hasTime && code.contains('m'));
    if (hasDate) return _CellFormat.dateTime;
    // `_nonElapsedBracket` は経過時間の角括弧を残すので、剥がした後でも拾える。
    if (_elapsedBracket.hasMatch(code)) return _CellFormat.elapsed;
    if (hasTime) return _CellFormat.time;
    return _CellFormat.other;
  }

  List<List<String?>> _readRows(
    XmlDocument worksheet,
    List<String> sharedStrings,
    List<_CellFormat> cellFormats,
    bool uses1904DateSystem,
  ) {
    // 行は疎に持つ。`<row r="1048576"/>` のように上限ぎりぎりの行があると、
    // 行番号のぶんだけリストを確保するだけでメモリと時間を使う。長さは
    // 「値を持つセルがある最終行」で決める（ADR-22 / FR-08）。
    final rows = <int, List<String?>>{};
    var lastRowWithValue = 0;
    // `row@r` / `c@r` は省略可能で、省略時は出現順に並んでいるとみなす。
    // 属性が無い行を捨てると、仕様上有効なファイルが空シートとして読まれる。
    var previousRowNumber = 0;
    for (final rowElement in worksheet.findAllElements(
      'row',
      namespace: _anyNamespace,
    )) {
      final declaredRow = int.tryParse(rowElement.getAttribute('r') ?? '');
      final rowNumber = declaredRow ?? previousRowNumber + 1;
      if (rowNumber < 1 || rowNumber > _maxRows) continue;
      previousRowNumber = rowNumber;

      final row = rows[rowNumber] ?? <String?>[];
      var previousColumn = -1;
      for (final cell in rowElement.findElements(
        'c',
        namespace: _anyNamespace,
      )) {
        final declaredColumn = _columnIndex(cell.getAttribute('r'));
        final column = declaredColumn ?? previousColumn + 1;
        if (column < 0 || column >= _maxColumns) continue;
        previousColumn = column;

        while (row.length <= column) {
          row.add(null);
        }
        final value = _readCell(
          cell,
          sharedStrings,
          cellFormats,
          uses1904DateSystem,
        );
        // 空セルは行の中では `null` として残す（FR-22 / FR-24）。列の対応が
        // ずれないよう、位置の記録（`previousColumn`）と代入は先に済ませる。
        row[column] = value;
        // ただし行数は伸ばさない。Excel はデータより下の行に書式だけを付けた
        // とき、値の無い `<c>` を持つ行を書き出す。それで長さを決めると、
        // 小さなファイルが 100 万行のシートになる。
        if (value == null) continue;
        rows[rowNumber] = row;
        if (rowNumber > lastRowWithValue) lastRowWithValue = rowNumber;
      }
    }
    return List<List<String?>>.generate(
      lastRowWithValue,
      (index) => rows[index + 1] ?? const <String?>[],
      growable: false,
    );
  }

  String? _readCell(
    XmlElement cell,
    List<String> sharedStrings,
    List<_CellFormat> cellFormats,
    bool uses1904DateSystem,
  ) {
    final type = cell.getAttribute('t');
    if (type == 'inlineStr') {
      return _richText(cell);
    }

    // 数式セルは計算せず式そのものを返す（ADR-13 の表記を維持）。ただし共有
    // 数式の従属セル（`<f t="shared" si="0"/>`）は式本体を持たないため、
    // ここで打ち切るとキャッシュ値まで失われる。
    final formula = cell
        .findElements('f', namespace: _anyNamespace)
        .firstOrNull
        ?.innerText;
    if (formula != null && formula.isNotEmpty) {
      return formula.startsWith('=') ? formula : '=$formula';
    }

    final rawValue = cell
        .findElements('v', namespace: _anyNamespace)
        .firstOrNull
        ?.innerText;
    if (rawValue == null) return null;
    final styleIndex = int.tryParse(cell.getAttribute('s') ?? '');
    final hasFormat =
        styleIndex != null &&
        styleIndex >= 0 &&
        styleIndex < cellFormats.length;
    final format = hasFormat ? cellFormats[styleIndex] : _CellFormat.other;
    return switch (type) {
      's' => _sharedString(rawValue, sharedStrings),
      'b' => _isTrue(rawValue) ? 'true' : 'false',
      _ => _formatNumericCell(rawValue, format, uses1904DateSystem),
    };
  }

  /// 日付・時刻セルの表記は ADR-13 の契約を維持しています。
  ///
  /// 日付のみの書式でも `2026-07-28T00:00:00.000Z` と時刻付きで出るのは
  /// 従来どおり。変更すると既存利用者の出力が変わるため、ここでは揃えない。
  String _formatNumericCell(
    String rawValue,
    _CellFormat format,
    bool uses1904DateSystem,
  ) {
    if (format == _CellFormat.other) return rawValue;
    final serial = double.tryParse(rawValue);
    if (serial == null) return rawValue;

    if (format == _CellFormat.time || format == _CellFormat.elapsed) {
      final seconds = (serial * Duration.secondsPerDay).round();
      // 経過時間（`[h]:mm:ss`）は24時間で折り返さないための指定なので、
      // 時を丸めない。30時間は `30:00:00`。
      final hour = format == _CellFormat.elapsed
          ? seconds ~/ Duration.secondsPerHour
          : seconds ~/ Duration.secondsPerHour % 24;
      final minute = seconds ~/ Duration.secondsPerMinute % 60;
      final second = seconds % 60;
      return '${_twoDigits(hour)}:${_twoDigits(minute)}:${_twoDigits(second)}';
    }

    final epoch = uses1904DateSystem
        ? DateTime.utc(1904)
        : DateTime.utc(1899, 12, 30);
    final dateTime = epoch.add(
      Duration(milliseconds: (serial * Duration.millisecondsPerDay).round()),
    );
    return dateTime.toIso8601String();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _sharedString(String rawIndex, List<String> sharedStrings) {
    final index = int.tryParse(rawIndex);
    if (index == null || index < 0 || index >= sharedStrings.length) {
      throw FormatException('Invalid shared-string index: $rawIndex');
    }
    return sharedStrings[index];
  }

  int? _columnIndex(String? reference) {
    if (reference == null) return null;
    var index = 0;
    var letters = 0;
    for (final codeUnit in reference.codeUnits) {
      if (codeUnit >= 65 && codeUnit <= 90) {
        index = index * 26 + codeUnit - 64;
        letters++;
      } else if (codeUnit >= 97 && codeUnit <= 122) {
        index = index * 26 + codeUnit - 96;
        letters++;
      } else {
        break;
      }
    }
    return letters == 0 ? null : index - 1;
  }

  String _resolveWorkbookTarget(String target) {
    final normalized = target.replaceAll(r'\', '/');
    if (normalized.startsWith('/')) return normalized.substring(1);
    if (normalized.startsWith('xl/')) return normalized;
    return 'xl/$normalized';
  }
}

/// 対象シートがワークブックに存在しないことを表します。
class XlsxSheetNotFoundException implements Exception {
  /// Creates an exception.
  const XlsxSheetNotFoundException(this.requestedSheet, this.availableSheets);

  /// 要求されたシート名。
  final String requestedSheet;

  /// 利用可能なシート名。
  final List<String> availableSheets;
}

/// セル値の解釈に必要な表示形式の分類。
///
/// 日付と日付時刻は出力が同一（ADR-13）なので区別しない。時刻と経過時間は、
/// 24時間で折り返すかどうかが違う。
enum _CellFormat { other, dateTime, time, elapsed }
