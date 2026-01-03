import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'model.dart';

/// XLSX のバイトを解析して [LocalizationSheet] に変換します。
///
/// 前提:
/// - 1行目はヘッダ行であること。1列目のヘッダは `key` でなければなりません。
/// - ヘッダの2列目以降はロケールコード（例: `en`, `ja`）です。
/// - 2行目以降は各行がキーと各ロケールの翻訳を持ちます。
class ExcelParser {
  LocalizationSheet parse(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    // Use the first sheet found
    final sheetName = excel.tables.keys.first;
    final table = excel.tables[sheetName]!;

    final rows = table.rows;
    final maxRows = rows.length;
    if (maxRows == 0) {
      return LocalizationSheet(locales: [], entries: []);
    }

    // Determine max columns from existing rows for robust handling across excel versions
    var maxCols = 0;
    for (final r in rows) {
      if (r.length > maxCols) maxCols = r.length;
    }

    // Read header
    final header = <String>[];
    for (var c = 0; c < maxCols; c++) {
      final cell = rows[0].length > c ? rows[0][c] : null;
      header.add(_cellToString(cell));
    }

    if (header.isEmpty || header[0].trim().toLowerCase() != 'key') {
      throw FormatException('First header cell must be "key"');
    }

    final locales = header.skip(1).where((h) => h.trim().isNotEmpty).toList();

    final entries = <LocalizationEntry>[];
    for (var r = 1; r < maxRows; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;
      final keyCell = row.isNotEmpty ? row[0] : null;
      final key = _cellToString(keyCell).trim();
      if (key.isEmpty) continue;

      final translations = <String, String?>{};
      for (var i = 0; i < locales.length; i++) {
        final colIndex = i + 1;
        final cell = row.length > colIndex ? row[colIndex] : null;
        final value = _cellToString(cell);
        translations[locales[i]] = value.isEmpty ? null : value;
      }

      entries.add(LocalizationEntry(key, translations));
    }

    return LocalizationSheet(locales: locales, entries: entries);
  }

  String _cellToString(Data? cell) {
    if (cell == null) return '';
    final value = cell.value;
    if (value == null) return '';
    return value.toString();
  }
}
