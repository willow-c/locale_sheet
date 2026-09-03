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

  /// Office Open XML の関係（relationship）名前空間。
  ///
  /// `r:id` のように接頭辞で参照されるが、接頭辞の綴りはファイルが自由に
  /// 決められる。属性は名前空間 URI で引く。
  static const _relationshipsNamespace =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

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
        .findAllElements('workbookPr')
        .any((element) => element.getAttribute('date1904') == '1');
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
    for (final relationship in relationships.findAllElements('Relationship')) {
      final id = relationship.getAttribute('Id');
      final target = relationship.getAttribute('Target');
      if (id != null && target != null) {
        targetsById[id] = _resolveWorkbookTarget(target);
      }
    }

    final sheets = <({String name, String path})>[];
    for (final sheet in workbook.findAllElements('sheet')) {
      final name = sheet.getAttribute('name');
      final relationshipId = sheet.getAttribute(
        'id',
        namespace: _relationshipsNamespace,
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
        .findAllElements('si')
        .map(
          (item) => item
              .findAllElements('t')
              // rPh はふりがなであって本文ではない。
              .where((text) => text.parentElement?.localName != 'rPh')
              .map((text) => text.innerText)
              .join(),
        )
        .toList(growable: false);
  }

  List<_CellFormat> _readCellFormats(Archive archive) {
    final document = _readXmlOrNull(archive, 'xl/styles.xml');
    if (document == null) return const [];

    // `numFmt` は条件付き書式（`dxfs`）の中にも現れる。ID の意味が別物なので
    // 文書全体を走査すると、セル書式の定義を無関係な書式で上書きしてしまう。
    final customFormats = <int, String>{};
    final numberFormats = document.findAllElements('numFmts').firstOrNull;
    final numberFormatElements =
        numberFormats?.findElements('numFmt') ?? const <XmlElement>[];
    for (final format in numberFormatElements) {
      final id = int.tryParse(format.getAttribute('numFmtId') ?? '');
      final code = format.getAttribute('formatCode');
      if (id != null && code != null) customFormats[id] = code;
    }

    final cellFormats = document.findAllElements('cellXfs').firstOrNull;
    if (cellFormats == null) return const [];
    return cellFormats
        .findElements('xf')
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
    18, 19, 20, 21, 45, 46, 47, //
    32, 33, 34, 35, 55, 56,
  };

  /// 角括弧セクションのうち、経過時間（`[h]` / `[mm]` / `[ss]`）以外を除く。
  ///
  /// `[Red]` や `[$USD]` を残したまま `d` / `y` / `s` を探すと、色や通貨の
  /// 綴りが日付・時刻の指定と誤認される。
  static final _nonElapsedBracket = RegExp(
    r'\[(?![hms]+\])[^\]]*\]',
    caseSensitive: false,
  );

  _CellFormat _classifyFormat(int id, String? customCode) {
    if (_builtinTimeFormatIds.contains(id)) return _CellFormat.time;
    if (_builtinDateFormatIds.contains(id)) return _CellFormat.dateTime;
    if (customCode == null) return _CellFormat.other;

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
    if (hasTime) return _CellFormat.time;
    return _CellFormat.other;
  }

  List<List<String?>> _readRows(
    XmlDocument worksheet,
    List<String> sharedStrings,
    List<_CellFormat> cellFormats,
    bool uses1904DateSystem,
  ) {
    final rows = <List<String?>>[];
    // `row@r` / `c@r` は省略可能で、省略時は出現順に並んでいるとみなす。
    // 属性が無い行を捨てると、仕様上有効なファイルが空シートとして読まれる。
    var previousRowNumber = 0;
    for (final rowElement in worksheet.findAllElements('row')) {
      final declaredRow = int.tryParse(rowElement.getAttribute('r') ?? '');
      final rowNumber = declaredRow ?? previousRowNumber + 1;
      if (rowNumber < 1 || rowNumber > _maxRows) continue;
      previousRowNumber = rowNumber;

      while (rows.length < rowNumber) {
        rows.add(<String?>[]);
      }
      final row = rows[rowNumber - 1];
      var previousColumn = -1;
      for (final cell in rowElement.findElements('c')) {
        final declaredColumn = _columnIndex(cell.getAttribute('r'));
        final column = declaredColumn ?? previousColumn + 1;
        if (column < 0 || column >= _maxColumns) continue;
        previousColumn = column;

        while (row.length <= column) {
          row.add(null);
        }
        row[column] = _readCell(
          cell,
          sharedStrings,
          cellFormats,
          uses1904DateSystem,
        );
      }
    }
    return rows;
  }

  String? _readCell(
    XmlElement cell,
    List<String> sharedStrings,
    List<_CellFormat> cellFormats,
    bool uses1904DateSystem,
  ) {
    final type = cell.getAttribute('t');
    if (type == 'inlineStr') {
      return cell.findAllElements('t').map((text) => text.innerText).join();
    }

    // 数式セルは計算せず式そのものを返す（ADR-13 の表記を維持）。ただし共有
    // 数式の従属セル（`<f t="shared" si="0"/>`）は式本体を持たないため、
    // ここで打ち切るとキャッシュ値まで失われる。
    final formula = cell.findElements('f').firstOrNull?.innerText;
    if (formula != null && formula.isNotEmpty) {
      return formula.startsWith('=') ? formula : '=$formula';
    }

    final rawValue = cell.findElements('v').firstOrNull?.innerText;
    if (rawValue == null) return null;
    final styleIndex = int.tryParse(cell.getAttribute('s') ?? '');
    final format = styleIndex != null && styleIndex < cellFormats.length
        ? cellFormats[styleIndex]
        : _CellFormat.other;
    return switch (type) {
      's' => _sharedString(rawValue, sharedStrings),
      'b' => rawValue == '1' ? 'true' : 'false',
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

    if (format == _CellFormat.time) {
      final seconds = (serial * Duration.secondsPerDay).round();
      final hour = seconds ~/ Duration.secondsPerHour % 24;
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
/// 日付と日付時刻は出力が同一（ADR-13）なので区別しない。
enum _CellFormat { other, dateTime, time }
