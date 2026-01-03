import 'package:locale_sheet/src/cli/logger.dart';
import 'package:test/test.dart';

void main() {
  /// SimpleLoggerがエラーなく標準出力・標準エラー出力を呼び出せることを検証
  /// Arrange-Act-Assertパターン
  test('SimpleLogger prints without error', () {
    // Arrange
    final logger = SimpleLogger();
    // Act
    logger.info('info message');
    logger.error('error message');
    // Assert: 標準出力内容はここでは検証しない（呼び出しが例外なく通ることのみ確認）
  });
}
