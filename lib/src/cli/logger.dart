import 'dart:io';

/// CLI やライブラリのメッセージ出力に使う簡易的なロガーのインターフェース。
abstract class Logger {
  /// Emit an informational message.
  void info(String message);

  /// Emit an error message.
  void error(String message);
}

/// デフォルトの簡易ロガー。標準出力/標準エラーにメッセージを出力します。
class SimpleLogger implements Logger {
  /// Writes an informational message to stdout.
  @override
  void info(String message) => stdout.writeln(message);

  /// Writes an error message to stderr.
  @override
  void error(String message) => stderr.writeln(message);
}
