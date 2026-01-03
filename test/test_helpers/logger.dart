import 'package:locale_sheet/src/cli/logger.dart';

/// テスト用の簡易 Logger 実装。
class TestLogger implements Logger {
  final infos = <String>[];
  final errors = <String>[];

  @override
  void info(String message) => infos.add(message);

  @override
  void error(String message) => errors.add(message);
}
