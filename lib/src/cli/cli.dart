import 'dart:io';

import 'package:args/command_runner.dart';

import '../../locale_sheet.dart';
import 'logger.dart';

/// ローカライズファイルをエクスポートするための CLI コマンド。
///
/// 使い方（コマンドライン）:
///
/// ```sh
/// locale_sheet export --input path/to/file.xlsx --format arb --out ./lib/l10n
/// ```
///
/// コンストラクタ引数:
/// - `logger`: ログ出力先を差し替えるための `Logger` 実装。未指定時は `SimpleLogger` を使います。
/// - `parser`: テストやカスタム解析のために `ExcelParser` を注入できます。未指定時はデフォルトの `ExcelParser()` を使います。
/// - `exporters`: 出力フォーマットを提供する `LocalizationExporter` のマップ。キーが `--format` に指定する値になります。
///
/// 注入可能にすることでユニットテスト時にパーサやエクスポーターを差し替えられます。
class ExportCommand extends Command<int> {
  @override
  final name = 'export';

  @override
  final description = 'ローカライズ用のExcelシートを指定された形式に変換します。';

  final Logger logger;
  final ExcelParser parser;

  // 利用可能なエクスポーターのマップ。
  // 新しいフォーマットを追加するには、ここに新しいエントリーを追加します。
  final Map<String, LocalizationExporter> _exporters;

  ExportCommand({
    Logger? logger,
    ExcelParser? parser,
    Map<String, LocalizationExporter>? exporters,
  }) : logger = logger ?? SimpleLogger(),
       parser = parser ?? ExcelParser(),
       _exporters = exporters ?? {'arb': ArbExporter()} {
    argParser.addOption(
      'input',
      abbr: 'i',
      help: '入力 .xlsx ファイルのパス。',
      mandatory: true,
    );
    argParser.addOption(
      'format',
      defaultsTo: 'arb',
      help: '出力フォーマット。',
      allowed: _exporters.keys.toList(),
    );
    argParser.addOption('out', abbr: 'o', defaultsTo: '.', help: '出力ディレクトリ。');
  }

  @override
  Future<int> run() async {
    final argResults = this.argResults;
    if (argResults == null) {
      logger.error('引数の解析に失敗しました。');
      return 64;
    }

    final inputPath = argResults['input'] as String;
    final format = argResults['format'] as String;
    final outDir = argResults['out'] as String;

    final exporter = _exporters[format];
    if (exporter == null) {
      logger.error('サポートされていないフォーマットです: $format');
      return 64;
    }

    try {
      final bytes = await File(inputPath).readAsBytes();
      final sheet = parser.parse(bytes);
      await exporter.export(sheet, outDir);
      logger.info('"$format" 形式のファイルを $outDir に正常に出力しました。');
      return 0;
    } catch (e) {
      logger.error('エラーが発生しました: $e');
      return 1;
    }
  }
}
