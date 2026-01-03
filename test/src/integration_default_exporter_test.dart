import 'dart:io';

import 'package:excel/excel.dart';
import 'package:locale_sheet/locale_sheet.dart';
import 'package:test/test.dart';

void main() {
  /// convertExcelToArb（デフォルトArbExporter利用）が正しくARBファイルを出力することを検証
  /// Arrange-Act-Assertパターン
  test('convertExcelToArb with default ArbExporter writes files', () async {
    // Arrange: XLSXバイト列を作成し一時ファイルに書き出し
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow(['key', 'en']);
    sheet.appendRow(['hello', 'Hello']);
    final bytes = excel.encode()!;

    final tmp = Directory.systemTemp.createTempSync(
      'integration_default_exporter',
    );
    final inFile = File('${tmp.path}/in.xlsx')..writeAsBytesSync(bytes);
    final outDir = '${tmp.path}/out';
    // Act: エクスポーター未指定で変換（デフォルトArbExporter使用）
    await convertExcelToArb(inputPath: inFile.path, outDir: outDir);
    // Assert: ARBファイルが生成され、@@localeが含まれる
    final arbFile = File('$outDir/app_en.arb');
    expect(arbFile.existsSync(), isTrue);
    final content = arbFile.readAsStringSync();
    expect(content, contains('@@locale'));
    // Cleanup
    tmp.deleteSync(recursive: true);
  });
}
