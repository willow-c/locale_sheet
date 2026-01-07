import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:locale_sheet/locale_sheet.dart';
import 'package:locale_sheet/src/cli/logger.dart';

/// ローカライズファイルをエクスポートするための CLI コマンド。
/// 注入可能にすることでユニットテスト時にパーサやエクスポーターを差し替えられます。
class ExportCommand extends Command<int> {
  /// Create a new `ExportCommand`.
  ///
  /// Optional dependencies can be injected for testing.
  ExportCommand({
    Logger? logger,
    ExcelParser? parser,
    Map<String, LocalizationExporter>? exporters,
  }) : logger = logger ?? SimpleLogger(),
       parser = parser ?? ExcelParser(),
       _exporters = exporters ?? {'arb': ArbExporter()} {
    final allowedFormats = _exporters.keys.toList();

    argParser
      ..addOption(
        'input',
        abbr: 'i',
        help: '入力 .xlsx ファイルのパス。',
        mandatory: true,
      )
      ..addOption(
        'format',
        defaultsTo: 'arb',
        help: '出力フォーマット。',
        allowed: allowedFormats,
      )
      ..addOption('out', abbr: 'o', defaultsTo: '.', help: '出力ディレクトリ。')
      ..addOption(
        'default-locale',
        abbr: 'd',
        help:
            'Default locale to be used as the default language. '
            'If omitted, uses "en" if present or the first locale column.',
      );
  }

  /// The command name used by the `CommandRunner`.
  @override
  final name = 'export';

  /// Short description shown in help text.
  @override
  final description = 'ローカライズ用のExcelシートを指定された形式に変換します。';

  /// Logger used to emit messages; injectable for tests.
  final Logger logger;

  /// Parser used to read Excel bytes into internal sheet model.
  final ExcelParser parser;

  // 利用可能なエクスポーターのマップ。
  // 新しいフォーマットを追加するには、ここに新しいエントリーを追加します。
  final Map<String, LocalizationExporter> _exporters;

  /// Execute the export command.
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
      final userProvidedDefault = argResults.wasParsed('default-locale');
      String defaultLocale;
      if (userProvidedDefault) {
        final requested = argResults['default-locale'] as String?;
        if (requested == null || !sheet.locales.contains(requested)) {
          final localesList = sheet.locales.join(', ');
          final message =
              'Specified default-locale "${requested ?? ''}" not found '
              'in the sheet locales: $localesList';
          logger.error(message);
          return 64;
        }
        defaultLocale = requested;
      } else {
        if (sheet.locales.contains('en')) {
          defaultLocale = 'en';
        } else if (sheet.locales.isNotEmpty) {
          defaultLocale = sheet.locales.first;
        } else {
          defaultLocale = 'en';
        }
      }

      await exporter.export(sheet, outDir, defaultLocale: defaultLocale);
      logger.info('"$format" 形式のファイルを $outDir に正常に出力しました。');
      return 0;
    } on Exception catch (e) {
      logger.error('エラーが発生しました: $e');
      return 1;
    }
  }
}
