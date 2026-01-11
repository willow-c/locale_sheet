import 'dart:io' as io;
import 'dart:typed_data';

import 'package:locale_sheet/src/core/parser.dart' show ExcelParser;
import 'package:locale_sheet/src/exporters/arb_exporter.dart' show ArbExporter;
import 'package:locale_sheet/src/exporters/exporter.dart'
    show LocalizationExporter;

export 'src/cli/cli.dart';
export 'src/core/model.dart';
export 'src/core/parser.dart';
export 'src/exporters/arb_exporter.dart';
export 'src/exporters/exporter.dart';

/// Excel のバイト列を解析し、渡された [exporter] を使って出力します。
///
/// これはバイト列を受け取り注入可能なエクスポーターで出力する、
/// コアでテストしやすい関数です。
///
/// [sheetName] を指定した場合はその名前のシートを解析します。null
/// の場合（オプションを省略した場合）はワークブックの最初のシートが使
/// 用されます。指定したシート名が存在しないときは `SheetNotFoundException`
/// を投げます。
Future<void> convertExcelBytesToArb(
  Uint8List bytes,
  LocalizationExporter exporter,
  String outDir, {
  ExcelParser? parser,
  String defaultLocale = 'en',
  String? sheetName,
  String? descriptionHeader,
}) async {
  final usedParser = parser ?? ExcelParser();
  final sheet = usedParser.parse(
    bytes,
    sheetName: sheetName,
    descriptionHeader: descriptionHeader,
  );
  await exporter.export(sheet, outDir, defaultLocale: defaultLocale);
}

/// ファイルパスを読み込み、別のエクスポーターが渡されない限り
/// デフォルトの `ArbExporter` を使う便利関数です。
///
/// 引数の `sheetName` を渡すとその名前のシートを解析します。`sheetName`
/// を省略または `null` にした場合はワークブックの最初のシートが使用
/// されます。指定したシートが存在しない場合は `SheetNotFoundException`
/// が発生します。
Future<void> convertExcelToArb({
  required String inputPath,
  required String outDir,
  ExcelParser? parser,
  LocalizationExporter? exporter,
  String defaultLocale = 'en',
  String? sheetName,
  String? descriptionHeader,
}) async {
  final bytes = await io.File(inputPath).readAsBytes();
  final usedExporter = exporter ?? ArbExporter();
  await convertExcelBytesToArb(
    bytes,
    usedExporter,
    outDir,
    parser: parser,
    defaultLocale: defaultLocale,
    sheetName: sheetName,
    descriptionHeader: descriptionHeader,
  );
}
