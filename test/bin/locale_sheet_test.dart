import 'dart:io';

import 'package:test/test.dart';

/// `bin/locale_sheet.dart` を実際にプロセスとして起動し、終了コードを検証する。
///
/// `ExportCommand` 単体のテストでは `run` の戻り値までしか確認できず、
/// エントリポイントが `UsageException` を捕まえて `exit(64)` する部分や、
/// 戻り値をプロセスの終了コードへ変換する部分が検証されない。
/// 要件定義の第5章で定めた終了コードは、最終的にここで決まる。
void main() {
  /// テスト実行中の Dart VM でエントリポイントを起動します。
  Future<ProcessResult> runCli(List<String> args) => Process.run(
    Platform.resolvedExecutable,
    ['bin/locale_sheet.dart', ...args],
  );

  /// コマンドを指定しない場合、使い方を標準エラーに出して終了コード64に
  /// なることを検証（何も実行していないのに成功として終わらない）
  /// Arrange-Act-Assertパターン
  test('exits with 64 when no command is given', () async {
    // Arrange & Act
    final result = await runCli([]);

    // Assert
    expect(result.exitCode, 64);
    expect(result.stderr, contains('Usage: locale_sheet'));
  });

  /// --help は明示的な要求なので終了コード0になることを検証
  /// Arrange-Act-Assertパターン
  test('exits with 0 when help is requested explicitly', () async {
    // Arrange & Act
    final result = await runCli(['--help']);

    // Assert
    expect(result.exitCode, 0);
  });

  /// 未知のオプションを指定した場合に終了コード64になることを検証
  /// Arrange-Act-Assertパターン
  test('exits with 64 on an unknown option', () async {
    // Arrange & Act
    final result = await runCli(['export', '--no-such-option']);

    // Assert
    expect(result.exitCode, 64);
  });

  /// 入力ファイルが存在しない場合に終了コード1になることを検証
  /// Arrange-Act-Assertパターン
  test('exits with 1 when the input file does not exist', () async {
    // Arrange & Act
    final result = await runCli([
      'export',
      '--input',
      'no_such_file.xlsx',
      '--no-color',
    ]);

    // Assert: 引数の誤りではなく実行時の失敗
    expect(result.exitCode, 1);
  });

  /// 正常に変換できた場合に終了コード0になり、ARBが生成されることを検証
  /// Arrange-Act-Assertパターン
  test('exits with 0 and writes ARB files on success', () async {
    // Arrange
    final tmp = Directory.systemTemp.createTempSync('locale_sheet_bin');

    try {
      // Act
      final result = await runCli([
        'export',
        '--input',
        'example/sample.xlsx',
        '--out',
        tmp.path,
        '--sheet-name',
        'Sheet2',
        '--no-color',
      ]);

      // Assert
      expect(result.exitCode, 0);
      final names = tmp.listSync().map((e) => e.uri.pathSegments.last).toList()
        ..sort();
      expect(names, ['app_fr.arb', 'app_ja.arb']);
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });
}
