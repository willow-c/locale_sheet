import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:locale_sheet/src/core/xlsx_reader.dart';
import 'package:test/test.dart';

void main() {
  /// 重複した共有文字列があっても後続セルの参照位置を維持することを検証
  test('read preserves duplicate shared-string indices', () {
    // Arrange
    final bytes = _workbookWithDuplicateSharedString();
    const reader = XlsxReader();

    // Act
    final sheet = reader.read(bytes);

    // Assert
    expect(sheet.sheetName, 'Sheet1');
    expect(sheet.rows[1][0], 'duplicate');
    expect(sheet.rows[1][1], 'value after duplicate');
  });
}

Uint8List _workbookWithDuplicateSharedString() {
  const spreadsheetNamespace =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  const officeRelationshipsNamespace =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  const packageRelationshipsNamespace =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  final archive = Archive()
    ..addFile(
      _xmlFile(
        'xl/workbook.xml',
        '<workbook xmlns="$spreadsheetNamespace" '
            'xmlns:r="$officeRelationshipsNamespace"> '
            '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/> '
            '</sheets></workbook>',
      ),
    )
    ..addFile(
      _xmlFile(
        'xl/_rels/workbook.xml.rels',
        '<Relationships xmlns="$packageRelationshipsNamespace"> '
            '<Relationship Id="rId1" Target="worksheets/sheet1.xml" '
            'Type="$officeRelationshipsNamespace/worksheet"/> '
            '</Relationships>',
      ),
    )
    ..addFile(
      _xmlFile(
        'xl/sharedStrings.xml',
        '<sst xmlns="$spreadsheetNamespace" count="5" uniqueCount="4"> '
            '<si><t>key</t></si> <si><t>en</t></si> '
            '<si><t>duplicate</t></si> <si><t>duplicate</t></si> '
            '<si><t>value after duplicate</t></si></sst>',
      ),
    )
    ..addFile(
      _xmlFile(
        'xl/worksheets/sheet1.xml',
        '<worksheet xmlns="$spreadsheetNamespace"><sheetData> '
            '<row r="1"><c r="A1" t="s"><v>0</v></c> '
            '<c r="B1" t="s"><v>1</v></c></row> '
            '<row r="2"><c r="A2" t="s"><v>3</v></c> '
            '<c r="B2" t="s"><v>4</v></c></row> '
            '</sheetData></worksheet>',
      ),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

ArchiveFile _xmlFile(String path, String contents) {
  final bytes = utf8.encode(contents);
  return ArchiveFile(path, bytes.length, bytes);
}
