import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:locale_sheet/src/core/model.dart';
import 'package:locale_sheet/src/core/model_helpers.dart';

/// XLSX のバイトを解析して [LocalizationSheet] に変換します。
///
/// 前提:
/// - 1行目はヘッダ行であること。
///   1列目のヘッダは `key` でなければなりません。
/// - ヘッダの2列目以降はロケールコード（例: `en`, `ja`）です。
/// - 2行目以降は各行がキーと各ロケールの翻訳を持ちます。

/// Thrown when a requested sheet name is not found.
class SheetNotFoundException implements Exception {
  /// Create a [SheetNotFoundException].
  ///
  /// [requestedSheet] is the name the caller attempted to open and
  /// [availableSheets] contains the list of sheets present in the workbook.
  SheetNotFoundException(this.requestedSheet, this.availableSheets);

  /// The sheet name that was requested.
  final String requestedSheet;

  /// The list of available sheet names in the workbook.
  final List<String> availableSheets;

  @override
  String toString() {
    final avail = availableSheets.join(', ');
    return 'Sheet "$requestedSheet" not found. Available sheets: $avail';
  }
}

/// Excel XLSX parser.
///
/// Provides utilities to parse XLSX byte streams into the internal
/// `LocalizationSheet` model.
class ExcelParser {
  /// Create a new [ExcelParser].
  ///
  /// An optional [decoder] can be provided for testing to override the
  /// default `Excel.decodeBytes` behavior.
  ExcelParser({Excel Function(Uint8List)? decoder})
    : _decoder = decoder ?? Excel.decodeBytes;

  final Excel Function(Uint8List) _decoder;

  /// Normalize a header for comparison against a requested locale.
  ///
  /// Trims surrounding whitespace, lower-cases, and treats `_` and `-` as the
  /// same separator, so `zh_TW` and `zh-tw` are considered the same request.
  static String _matchKey(String value) =>
      value.trim().toLowerCase().replaceAll('_', '-');

  /// Parse XLSX bytes and return a [LocalizationSheet].
  ///
  /// If [sheetName] is provided, attempts to read that sheet. If not
  /// provided, uses the first sheet found.
  ///
  /// If [locales] is provided, only the header columns matching those tags are
  /// treated as locale columns and every other column is ignored. Matching is
  /// case-insensitive and treats `_` and `-` as equivalent. A requested tag
  /// that is absent from the header row is a [FormatException], so typos fail
  /// loudly instead of silently dropping a language.
  ///
  /// If [locales] is omitted, the columns are selected by pattern matching
  /// (`isValidLocaleTag`) as before. That check is permissive — common column
  /// names such as `memo` also qualify — so the resulting selection and the
  /// ignored headers are both reported on [LocalizationSheet].
  LocalizationSheet parse(
    Uint8List bytes, {
    String? sheetName,
    String? descriptionHeader,
    List<String>? locales,
  }) {
    final excel = _decoder(bytes);
    final selectedSheetName =
        sheetName ??
        (excel.tables.keys.isNotEmpty
            ? excel.tables.keys.first
            : (throw SheetNotFoundException(
                '(first sheet)',
                excel.tables.keys.toList(),
              )));

    if (!excel.tables.containsKey(selectedSheetName)) {
      throw SheetNotFoundException(
        selectedSheetName,
        excel.tables.keys.toList(),
      );
    }

    final table = excel.tables[selectedSheetName]!;

    final rows = table.rows;
    final maxRows = rows.length;
    if (maxRows == 0) {
      return LocalizationSheet(locales: [], entries: []);
    }

    // Determine max columns from existing rows for robust handling
    // across different Excel library versions.
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
      throw const FormatException('First header cell must be "key"');
    }

    // If a description header is provided, find its column index in the
    // first row. This column will be treated as the description column and
    // excluded from the locale columns.
    int? descriptionColIndex;
    if (descriptionHeader != null) {
      // Prevent users from accidentally specifying the `key` column as the
      // description column. The first header cell must be `key`, so treating
      // it as a description column would be a user error.
      if (descriptionHeader.trim().toLowerCase() == 'key') {
        throw const FormatException("Description header cannot be 'key'");
      }
      for (var c = 0; c < header.length; c++) {
        if (header[c].trim().toLowerCase() ==
            descriptionHeader.trim().toLowerCase()) {
          descriptionColIndex = c;
          break;
        }
      }
      if (descriptionColIndex == null) {
        throw FormatException(
          'Description header "$descriptionHeader" not found in the first row',
        );
      }
      // Validate that the description column header is not itself a valid
      // locale tag. If it is, this likely indicates the user intended that
      // column to be a locale, not a description column, so fail early.
      final descHeader = header[descriptionColIndex].trim();
      if (isValidLocaleTag(descHeader)) {
        throw FormatException(
          'Description header "$descHeader" conflicts with a locale tag',
        );
      }
    }

    // Determine which header columns are locale columns.
    // Keep both the locale tag and the original column index
    // so we can map rows safely, and record what was left out so callers can
    // show the user which columns were and were not treated as locales.
    final requested = locales?.map(_matchKey).toSet();
    final selectedLocales = <String>[];
    final localeColIndices = <int>[];
    final ignoredHeaders = <String>[];
    for (var c = 1; c < header.length; c++) {
      if (descriptionColIndex != null && c == descriptionColIndex) continue;
      final h = header[c].trim();
      if (h.isEmpty) continue;
      final isLocale = requested == null
          ? isValidLocaleTag(h)
          : requested.contains(_matchKey(h));
      if (isLocale) {
        selectedLocales.add(h);
        localeColIndices.add(c);
      } else {
        ignoredHeaders.add(h);
      }
    }

    // 指定されたロケールが1行目に存在しない場合は、綴り間違いを黙って
    // 落とさないようエラーにする。
    if (locales != null) {
      final matched = selectedLocales.map(_matchKey).toSet();
      final missing = locales
          .where((l) => !matched.contains(_matchKey(l)))
          .toList();
      if (missing.isNotEmpty) {
        throw FormatException(
          'Locale column(s) not found in the first row: ${missing.join(', ')}',
        );
      }
    }

    final entries = <LocalizationEntry>[];
    for (var r = 1; r < maxRows; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;
      final keyCell = row.isNotEmpty ? row[0] : null;
      final key = _cellToString(keyCell).trim();
      if (key.isEmpty) continue;

      final translations = <String, String?>{};
      for (var i = 0; i < selectedLocales.length; i++) {
        final colIndex = localeColIndices[i];
        final cell = row.length > colIndex ? row[colIndex] : null;
        final value = _cellToString(cell);
        translations[selectedLocales[i]] = value.isEmpty ? null : value;
      }

      String? description;
      if (descriptionColIndex != null) {
        final descCell = row.length > descriptionColIndex
            ? row[descriptionColIndex]
            : null;
        final desc = _cellToString(descCell).trim();
        description = desc.isEmpty ? null : desc;
      }

      entries.add(
        LocalizationEntry(
          key,
          translations,
          description: description,
          placeholders: const <String, Placeholder>{},
        ),
      );
    }

    return LocalizationSheet(
      locales: selectedLocales,
      entries: entries,
      ignoredHeaders: ignoredHeaders,
    );
  }

  String _cellToString(Data? cell) {
    if (cell == null) return '';
    final value = cell.value;
    if (value == null) return '';
    return value.toString();
  }

  // Uses `isValidLocaleTag` from model_helpers.dart

  /// Return the list of sheet names present in the workbook represented
  /// by the provided XLSX bytes.
  List<String> getSheetNames(Uint8List bytes) {
    final excel = _decoder(bytes);
    return excel.tables.keys.toList();
  }
}
