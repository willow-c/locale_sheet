/// CLI やライブラリのメッセージ出力に使う簡易的なロガーのインターフェース。
abstract class Logger {
  void info(String message);
  void error(String message);
}

/// デフォルトの簡易ロガー。標準出力/標準エラーにメッセージを出力します。
class SimpleLogger implements Logger {
  @override
  void info(String message) => print(message);

  @override
  void error(String message) => print(message);
}
