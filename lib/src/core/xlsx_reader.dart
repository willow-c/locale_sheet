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

  /// Reads one worksheet from [bytes].
  XlsxSheetData read(Uint8List bytes, {String? sheetName}) {
    final archive = _decodeArchive(bytes);
    final workbook = _readXml(archive, 'xl/workbook.xml');
    final relationships = _readXml(
      archive,
      'xl/_rels/workbook.xml.rels',
    );

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
      final relationshipId = sheet.getAttribute('r:id');
      final path = targetsById[relationshipId];
      if (name != null && path != null) {
        sheets.add((name: name, path: path));
      }
    }

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

  Archive _decodeArchive(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } on Object catch (error) {
      throw FormatException('Invalid XLSX archive: $error');
    }
  }

  XmlDocument _readXml(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null) {
      throw FormatException('Required XLSX entry is missing: $path');
    }
    try {
      return XmlDocument.parse(utf8.decode(file.content as List<int>));
    } on Object catch (error) {
      throw FormatException('Invalid XML in XLSX entry "$path": $error');
    }
  }

  List<String> _readSharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return const [];

    final document = _readXml(archive, 'xl/sharedStrings.xml');
    return document
        .findAllElements('si')
        .map(
          (item) => item
              .findAllElements('t')
              .where((text) => text.parentElement?.localName != 'rPh')
              .map((text) => text.innerText)
              .join(),
        )
        .toList(growable: false);
  }

  List<_CellFormat> _readCellFormats(Archive archive) {
    if (archive.findFile('xl/styles.xml') == null) return const [];
    final document = _readXml(archive, 'xl/styles.xml');
    final customFormats = <int, String>{};
    for (final format in document.findAllElements('numFmt')) {
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

  _CellFormat _classifyFormat(int id, String? customCode) {
    if ({18, 19, 20, 21, 45, 46, 47}.contains(id)) {
      return _CellFormat.time;
    }
    if (id == 22) return _CellFormat.dateTime;
    if ({14, 15, 16, 17}.contains(id)) return _CellFormat.date;
    if (customCode == null) return _CellFormat.other;

    final code = customCode
      .replaceAll(RegExp('"[^"]*"'), '')
      .replaceAll(RegExp(r'\\.'), '')
        .toLowerCase();
    final hasDate = code.contains('d') || code.contains('y');
    final hasTime = code.contains('h') || code.contains('s');
    if (hasDate && hasTime) return _CellFormat.dateTime;
    if (hasDate) return _CellFormat.date;
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
    for (final rowElement in worksheet.findAllElements('row')) {
      final rowNumber = int.tryParse(rowElement.getAttribute('r') ?? '');
      if (rowNumber == null || rowNumber < 1) continue;

      while (rows.length < rowNumber) {
        rows.add(<String?>[]);
      }
      final row = rows[rowNumber - 1];
      for (final cell in rowElement.findElements('c')) {
        final column = _columnIndex(cell.getAttribute('r'));
        if (column == null) continue;
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

    final formula = cell.findElements('f').firstOrNull?.innerText;
    if (formula != null) return formula.startsWith('=') ? formula : '=$formula';

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

enum _CellFormat { other, date, dateTime, time }
