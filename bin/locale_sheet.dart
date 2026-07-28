import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:locale_sheet/locale_sheet.dart';
import 'package:locale_sheet/src/cli/exit_codes.dart';

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
    exit(exitUsage);
  }

  try {
    final result = await runner.run(arguments);
    if (result is int && result != exitSuccess) exit(result);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(exitUsage);
  } on Object catch (e, stackTrace) {
    // ここに来るのは想定外の失敗（`Error` を含む）。握り潰さずスタック
    // トレースを出したうえで、文書化された終了コードで終える。
    // 何も出さずに 255 で落ちると、利用者は原因も区分も分からない。
    stderr
      ..writeln('Unexpected error: $e')
      ..writeln(stackTrace);
    exit(exitSoftware);
  }
}
