import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:locale_sheet/locale_sheet.dart';
import 'package:test/test.dart';

import '../test_helpers/logger.dart';

/// 出荷している `example/sample.xlsx` を実際に読み込み、CLI と同じ経路で
/// ARB を生成して内容を全文で検証する e2e テスト。
///
/// 他のテストは `Excel.createExcel()` でメモリ上に組み立てたワークブックを
/// 使うため、実際の表計算ソフトが書き出したファイル（共有文字列を参照する
/// 形式）の解析経路が検証されない。本テストはその経路と、モデルから ARB を
/// 書き出す最終段までを通しで確認し、同時に配布しているサンプル自体の
/// 回帰も検出する。
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('locale_sheet_e2e');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// CLI と同じ `CommandRunner` 経由で export を実行します。
  /// パーサもエクスポーターも実物を使い、ロガーだけテスト用に差し替えます。
  Future<int?> runExport(List<String> extraArgs) {
    final runner = CommandRunner<int>('locale_sheet', 'e2e')
      ..addCommand(ExportCommand(logger: TestLogger()));
    return runner.run([
      'export',
      '--input',
      'example/sample.xlsx',
      '--out',
      tmp.path,
      ...extraArgs,
    ]);
  }

  String readArb(String fileName) =>
      File('${tmp.path}/$fileName').readAsStringSync();

  List<String> outputFileNames() =>
      tmp.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  /// 実ファイルの Sheet1 を説明列付きで変換し、生成される全 ARB の内容を検証
  /// Arrange-Act-Assertパターン
  test('exports Sheet1 with descriptions from the real workbook', () async {
    // Arrange / Act
    final code = await runExport([
      '--sheet-name',
      'Sheet1',
      '--default-locale',
      'en',
      '--description-header',
      'description',
    ]);

    // Assert: ロケール列は5つ。`description` と `備考` はロケールとして扱われない
    expect(code, equals(0));
    expect(outputFileNames(), [
      'app_en.arb',
      'app_ja.arb',
      'app_zh.arb',
      'app_zh_Hant_HK.arb',
      'app_zh_TW.arb',
    ]);

    // デフォルトロケールにのみ `@<key>` メタデータが出力される
    expect(readArb('app_en.arb'), '''
{
  "@bye": {
    "description": "the text 'Goodbye'"
  },
  "bye": "Goodbye",
  "@hello": {
    "description": "the text 'Hello'"
  },
  "hello": "Hello",
  "@likeFoodFluit": {},
  "likeFoodFluit": "I like {food} and {fluit}.",
  "@@locale": "en"
}''');

    // 非デフォルトロケールにはメタデータを含めない
    expect(readArb('app_ja.arb'), '''
{
  "bye": "さようなら",
  "hello": "こんにちは",
  "likeFoodFluit": "私は{food}と{fluit}が好き",
  "@@locale": "ja"
}''');

    // ハイフン区切りのヘッダはファイル名も @@locale もアンダースコアに正規化される
    expect(readArb('app_zh_Hant_HK.arb'), '''
{
  "bye": "再見",
  "hello": "你好",
  "likeFoodFluit": "我喜歡{food}和{fluit}",
  "@@locale": "zh_Hant_HK"
}''');
  });

  /// 自動検出したプレースホルダが ARB のメタデータとして書き出されることを検証
  /// Arrange-Act-Assertパターン
  test('writes auto-detected placeholders into the default ARB', () async {
    // Arrange / Act
    final code = await runExport([
      '--sheet-name',
      'Sheet1',
      '--default-locale',
      'en',
      '--description-header',
      'description',
      '--auto-detect-placeholders',
      '--treat-undefined-placeholders',
      'add',
    ]);

    // Assert: `@<key>.placeholders` に検出結果が出力される
    expect(code, equals(0));
    expect(readArb('app_en.arb'), '''
{
  "@bye": {
    "description": "the text 'Goodbye'"
  },
  "bye": "Goodbye",
  "@hello": {
    "description": "the text 'Hello'"
  },
  "hello": "Hello",
  "@likeFoodFluit": {
    "placeholders": {
      "food": {
        "type": "String",
        "source": "detected"
      },
      "fluit": {
        "type": "String",
        "source": "detected"
      }
    }
  },
  "likeFoodFluit": "I like {food} and {fluit}.",
  "@@locale": "en"
}''');
  });

  /// 説明列を指定しない場合、ロケールでない列が単に無視されることを検証
  /// Arrange-Act-Assertパターン
  test('ignores non-locale columns without a description header', () async {
    // Arrange / Act
    final code = await runExport([
      '--sheet-name',
      'Sheet1',
      '--default-locale',
      'en',
    ]);

    // Assert: `description` 列は説明として使われず、専用の ARB も作られない
    expect(code, equals(0));
    expect(outputFileNames(), [
      'app_en.arb',
      'app_ja.arb',
      'app_zh.arb',
      'app_zh_Hant_HK.arb',
      'app_zh_TW.arb',
    ]);
    expect(readArb('app_en.arb'), '''
{
  "@bye": {},
  "bye": "Goodbye",
  "@hello": {},
  "hello": "Hello",
  "@likeFoodFluit": {},
  "likeFoodFluit": "I like {food} and {fluit}.",
  "@@locale": "en"
}''');
  });

  /// シート指定で別のロケール構成を持つシートを変換し、`en` が無い場合に
  /// 最初のロケール列がデフォルトになることを検証
  /// Arrange-Act-Assertパターン
  test('exports Sheet2 and falls back to the first locale', () async {
    // Arrange / Act
    final code = await runExport(['--sheet-name', 'Sheet2']);

    // Assert: Sheet2 のロケールは ja と fr のみ
    expect(code, equals(0));
    expect(outputFileNames(), ['app_fr.arb', 'app_ja.arb']);

    // `en` 列が無いため最初のロケール `ja` がデフォルトとなり、
    // 説明が無いので `@<key>` は空オブジェクトになる
    expect(readArb('app_ja.arb'), '''
{
  "@bye": {},
  "bye": "さようなら",
  "@hello": {},
  "hello": "こんにちは",
  "@@locale": "ja"
}''');
    expect(readArb('app_fr.arb'), '''
{
  "bye": "Au revoir",
  "hello": "Bonjour",
  "@@locale": "fr"
}''');
  });
}
