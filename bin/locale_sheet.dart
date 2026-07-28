import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:locale_sheet/locale_sheet.dart';

Future<void> main(List<String> arguments) async {
  final runner = CommandRunner<int>(
    'locale_sheet',
    'A command-line tool for managing localization sheets.',
  )..addCommand(ExportCommand());

  // 引数を1つも与えられていない場合、実行すべきコマンドが無い。
  // `CommandRunner` は使い方を標準出力に表示して null を返すため、
  // そのままだと「何もしていないのに終了コード 0」になり、呼び出し側の
  // スクリプトが失敗に気付けない。使い方は標準エラー出力に出して 64 で終える。
  // `--help` のように明示的に要求された場合は、下の通常経路で 0 を返す。
  if (arguments.isEmpty) {
    stderr.writeln(runner.usage);
    exit(64);
  }

  try {
    final result = await runner.run(arguments);
    if (result is int && result != 0) exit(result);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}
