import 'package:args/command_runner.dart';
import 'logger.dart';

/// CLI 用のコマンドアダプター。ロガーとコンバータを注入可能にして
/// テストしやすくしています。
class ExportCommand extends Command<int> {
  @override
  final name = 'export';

  @override
  final description = 'Excel ファイルからロケールを読み取り、ARB ファイルとして出力します。';

  final Logger logger;
  final Future<void> Function(String inputPath, String outDir) converter;

  ExportCommand({
    Logger? logger,
    Future<void> Function(String inputPath, String outDir)? converter,
  }) : logger = logger ?? SimpleLogger(),
       converter =
           converter ??
           ((inputPath, outDir) async => throw UnimplementedError()) {
    argParser.addOption('input', abbr: 'i', help: '入力 .xlsx ファイルのパス');
    argParser.addOption(
      'format',
      defaultsTo: 'arb',
      help: '出力形式（現状は "arb" のみサポート）',
    );
    argParser.addOption('out', abbr: 'o', defaultsTo: '.', help: '出力先ディレクトリ');
  }

  @override
  Future<int> run() async {
    if (argResults == null) {
      logger.error('引数が正しく解析されていません（argResults が null）');
      return 64;
    }
    final input = argResults?['input'] as String?;
    final format = argResults?['format'] as String;
    final out = argResults?['out'] as String;

    if (input == null) {
      logger.error('入力ファイルが指定されていません（--input を指定してください）');
      return 64;
    }

    if (format != 'arb') {
      logger.error('サポートされていない出力形式です: $format');
      return 64;
    }

    try {
      await converter(input, out);
      logger.info('ARB ファイルを $out に出力しました');
      return 0;
    } catch (e) {
      logger.error('処理に失敗しました: $e');
      return 1;
    }
  }
}
