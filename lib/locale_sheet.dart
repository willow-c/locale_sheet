library;

export 'src/core/model.dart';
export 'src/core/parser.dart';
export 'src/exporters/exporter.dart';
export 'src/exporters/arb_exporter.dart';
export 'src/cli/cli.dart';

import 'dart:io' as io;
import 'dart:typed_data';

import 'src/core/parser.dart' show ExcelParser;
import 'src/exporters/arb_exporter.dart' show ArbExporter;
import 'src/exporters/exporter.dart' show LocalizationExporter;

/// Excel のバイト列を解析し、渡された [exporter] を使って出力します。
///
/// これはバイト列を受け取り注入可能なエクスポーターで出力する、
/// コアでテストしやすい関数です。
Future<void> convertExcelBytesToArb(
  Uint8List bytes,
  LocalizationExporter exporter,
  String outDir, {
  ExcelParser? parser,
}) async {
  final usedParser = parser ?? ExcelParser();
  final sheet = usedParser.parse(bytes);
  await exporter.export(sheet, outDir);
}

/// ファイルパスを読み込み、別のエクスポーターが渡されない限り
/// デフォルトの `ArbExporter` を使う便利関数です。
Future<void> convertExcelToArb({
  required String inputPath,
  required String outDir,
  ExcelParser? parser,
  LocalizationExporter? exporter,
}) async {
  final bytes = await io.File(inputPath).readAsBytes();
  final usedExporter = exporter ?? ArbExporter();
  await convertExcelBytesToArb(bytes, usedExporter, outDir, parser: parser);
}
