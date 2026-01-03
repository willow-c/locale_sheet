import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:locale_sheet/locale_sheet.dart';

Future<void> main(List<String> arguments) async {
  final runner = CommandRunner<int>(
    'locale_sheet',
    'A command-line tool for managing localization sheets.',
  )..addCommand(ExportCommand());
  try {
    final result = await runner.run(arguments);
    if (result is int && result != 0) exit(result);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}
