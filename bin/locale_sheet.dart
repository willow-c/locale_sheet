import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:locale_sheet/locale_sheet.dart';

class ExportCommand extends Command<int> {
  @override
  final name = 'export';

  @override
  final description = 'Export locales from an Excel file to ARB files.';

  ExportCommand({
    required Future<void> Function(String input, String out) converter,
  }) {
    argParser.addOption('input', abbr: 'i', help: 'Path to input .xlsx file');
    argParser.addOption(
      'format',
      defaultsTo: 'arb',
      help: 'Output format (currently only "arb" supported)',
    );
    argParser.addOption(
      'out',
      abbr: 'o',
      defaultsTo: '.',
      help: 'Output directory',
    );
  }

  @override
  Future<int> run() async {
    final input = argResults?['input'] as String?;
    final format = argResults?['format'] as String;
    final out = argResults?['out'] as String;

    if (input == null) {
      stderr.writeln('Missing --input');
      return 64;
    }

    if (format != 'arb') {
      stderr.writeln('Unsupported format: $format');
      return 64;
    }

    try {
      await convertExcelToArb(inputPath: input, outDir: out);
      stdout.writeln('Exported ARB files to $out');
      return 0;
    } catch (e) {
      stderr.writeln('Failed: $e');
      return 1;
    }
  }
}

Future<void> main(List<String> arguments) async {
  final runner =
      CommandRunner<int>('locale_sheet', 'locale_sheet のコマンドラインインターフェース')
        ..addCommand(
          ExportCommand(
            converter: (input, out) =>
                convertExcelToArb(inputPath: input, outDir: out),
          ),
        );
  try {
    final result = await runner.run(arguments);
    if (result is int && result != 0) exit(result);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}
