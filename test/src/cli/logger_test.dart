import 'package:locale_sheet/src/cli/logger.dart';
import 'package:test/test.dart';

void main() {
  /// SimpleLoggerがエラーなく標準出力・標準エラー出力を呼び出せることを検証
  /// Arrange-Act-Assertパターン
  test('SimpleLogger prints without error', () {
    // Arrange
    final _ = SimpleLogger()
      // Act
      ..info('info message')
      ..error('error message');
    // Assert: 標準出力内容はここでは検証しない。
    // 呼び出しが例外なく通ることのみ確認する。
  });

  test('SimpleLogger extras run without throwing', () {
    final _ = SimpleLogger()
      ..infoOptions({
        'input': 'a.xlsx',
        'format': 'arb',
        'out': '.',
      })
      ..infoAvailableSheets([
        'Sheet1',
        'Sheet2',
      ])
      ..infoSheetLocales(
        'Sheet1',
        ['en', 'ja'],
      );

    // No assertions: just ensure methods run without throwing.
    // This records coverage for the formatter methods.
  });

  test('SimpleLogger default/result/error run without throwing', () {
    final _ = SimpleLogger()
      ..infoDefaultLocale('ja')
      ..infoResult('arb', './lib/l10n')
      ..infoErrorResult('something failed');
  });
}
