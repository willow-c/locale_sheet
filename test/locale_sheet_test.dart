import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:locale_sheet/locale_sheet.dart';
import 'package:test/test.dart';

/// 公開バレル（`package:locale_sheet/locale_sheet.dart`）が提供する
/// 変換関数の振る舞いを検証する。
///
/// CLI を経由しないライブラリ利用の経路であり、`ExportRunner` のテストでは
/// 通らない。引数がパーサとエクスポーターへ正しく渡ることを確認する。
void main() {
  /// key/en/ja の3列と、ロケールでない `memo` 列を持つワークブックを作る。
  Uint8List sampleBytes() {
    final excel = Excel.createExcel();
    excel['Sheet1']
      ..appendRow([
        TextCellValue('key'),
        TextCellValue('en'),
        TextCellValue('ja'),
        TextCellValue('memo'),
      ])
      ..appendRow([
        TextCellValue('hello'),
        TextCellValue('Hello'),
        TextCellValue('こんにちは'),
        TextCellValue('a note'),
      ]);
    return Uint8List.fromList(excel.encode()!);
  }

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('locale_sheet_public_api');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  List<String> outputNames() =>
      tmp.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  /// convertExcelBytesToArbがバイト列から直接ARBを生成することを検証
  /// Arrange-Act-Assertパターン
  test('convertExcelBytesToArb writes ARB files from bytes', () async {
    // Arrange
    final bytes = sampleBytes();

    // Act
    await convertExcelBytesToArb(bytes, ArbExporter(), tmp.path);

    // Assert: memo もロケールとして扱われる（自動判定は緩い / ADR-01）
    expect(outputNames(), ['app_en.arb', 'app_ja.arb', 'app_memo.arb']);
    final en =
        jsonDecode(File('${tmp.path}/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(en['hello'], 'Hello');
    expect(en['@@locale'], 'en');
  });

  /// localesを指定するとロケール列を明示できることを検証
  /// Arrange-Act-Assertパターン
  test('convertExcelBytesToArb honors the locales argument', () async {
    // Arrange
    final bytes = sampleBytes();

    // Act
    await convertExcelBytesToArb(
      bytes,
      ArbExporter(),
      tmp.path,
      locales: ['en', 'ja'],
    );

    // Assert: memo が除外される
    expect(outputNames(), ['app_en.arb', 'app_ja.arb']);
  });

  /// convertExcelToArbがファイルパスから読み込み、既定でArbExporterを使うことを検証
  /// Arrange-Act-Assertパターン
  test('convertExcelToArb reads a file and defaults to ArbExporter', () async {
    // Arrange
    final input = File('${tmp.path}/in.xlsx')..writeAsBytesSync(sampleBytes());
    final outDir = '${tmp.path}/out';

    // Act: exporter を渡さない
    await convertExcelToArb(
      inputPath: input.path,
      outDir: outDir,
      locales: ['en'],
    );

    // Assert
    final produced = Directory(
      outDir,
    ).listSync().map((e) => e.uri.pathSegments.last).toList();
    expect(produced, ['app_en.arb']);
  });

  /// defaultLocaleに応じて欠けた翻訳が補完されることを検証
  /// Arrange-Act-Assertパターン
  test('convertExcelBytesToArb falls back to the default locale', () async {
    // Arrange: ja の翻訳が空のエントリ
    final excel = Excel.createExcel();
    excel['Sheet1']
      ..appendRow([
        TextCellValue('key'),
        TextCellValue('en'),
        TextCellValue('ja'),
      ])
      ..appendRow([TextCellValue('hello'), TextCellValue('Hello')]);
    final bytes = Uint8List.fromList(excel.encode()!);

    // Act
    await convertExcelBytesToArb(bytes, ArbExporter(), tmp.path);

    // Assert: 既定の defaultLocale は 'en' なので ja に en の値が入る
    final ja =
        jsonDecode(File('${tmp.path}/app_ja.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(ja['hello'], 'Hello');
  });

  /// 指定シートが存在しない場合にSheetNotFoundExceptionが伝播することを検証
  /// Arrange-Act-Assertパターン
  test('convertExcelBytesToArb propagates SheetNotFoundException', () async {
    // Arrange
    final bytes = sampleBytes();

    // Act & Assert: CLI と違い終了コードにはならず、例外がそのまま伝わる
    expect(
      () => convertExcelBytesToArb(
        bytes,
        ArbExporter(),
        tmp.path,
        sheetName: 'NoSuchSheet',
      ),
      throwsA(isA<SheetNotFoundException>()),
    );
  });
}
