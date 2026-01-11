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
        help: 'Path to the input .xlsx file.',
        mandatory: true,
      )
      ..addOption(
        'format',
        defaultsTo: 'arb',
        help: 'Output format.',
        allowed: allowedFormats,
      )
      ..addOption('out', abbr: 'o', defaultsTo: '.', help: 'Output directory.')
      ..addOption(
        'default-locale',
        abbr: 'd',
        help:
            'Default locale to be used as the default language. '
            'If omitted, uses "en" if present or the first '
            'locale column.',
      )
      ..addOption(
        'sheet-name',
        help:
            'Name of the sheet to convert. '
            'If omitted, the first sheet in the workbook is used.',
      )
      ..addOption(
        'description-header',
        help:
            'Header text to locate the description column in the first row. '
            'If provided, the parser will search the first row for this text. '
            'Found column will be used as the per-key description; if not '
            'found the command will fail.',
      )
      ..addFlag(
        'color',
        defaultsTo: true,
        help: 'Enable color output in logs.',
      );
  }

  /// The command name used by the `CommandRunner`.
  @override
  final name = 'export';

  /// Short description shown in help text.
  @override
  final description =
      'Convert a localization Excel sheet to the specified format.';

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
      logger.error('Failed to parse arguments.');
      return 64;
    }

    final inputPath = argResults['input'] as String;
    final format = argResults['format'] as String;
    final outDir = argResults['out'] as String;
    final useColor = argResults['color'] as bool? ?? true;

    // If the injected logger is the default `SimpleLogger`, recreate it
    // with the configured color setting.
    final effectiveLogger = (logger is SimpleLogger)
        ? SimpleLogger(color: useColor)
        : logger;

    // Prepare error emission helper below.

    // Helper to emit error messages once. Avoid duplicate output when the
    // injected `logger` and the `effectiveLogger` would both write the same
    // content to the console (for example, two SimpleLogger instances).
    void emitError(String msg) {
      if (identical(logger, effectiveLogger)) {
        // Single logger instance (likely a test logger) — emit only via
        // `error` so tests that inspect `errors` still observe it.
        logger.error(msg);
        return;
      }
      if (logger is SimpleLogger && effectiveLogger is SimpleLogger) {
        // Both are SimpleLogger instances — prefer the structured Result line
        // to avoid duplicate console output.
        effectiveLogger.infoErrorResult(msg);
        return;
      }
      // Fallback: emit both for maximum compatibility.
      logger.error(msg);
      effectiveLogger.infoErrorResult(msg);
    }

    // Header with timestamp + command summary
    final timestamp = DateTime.now().toIso8601String();
    final cmdSummary =
        'export --input $inputPath --format $format --out $outDir';
    effectiveLogger
      ..info('[INFO] $timestamp  $cmdSummary')
      ..infoOptions(<String, Object?>{
        'input': inputPath,
        'format': format,
        'out': outDir,
        'sheet-name': argResults.wasParsed('sheet-name')
            ? argResults['sheet-name'] as String?
            : null,
        'default-locale': argResults.wasParsed('default-locale')
            ? argResults['default-locale'] as String?
            : null,
        'description-header': argResults.wasParsed('description-header')
            ? argResults['description-header'] as String?
            : null,
      });

    final exporter = _exporters[format];
    if (exporter == null) {
      final msg = 'Unsupported format: $format';
      emitError(msg);
      return 64;
    }

    try {
      final bytes = await File(inputPath).readAsBytes();
      // Log available sheets found in the workbook.
      var availableSheets = <String>[];
      try {
        availableSheets = parser.getSheetNames(bytes);
        effectiveLogger.infoAvailableSheets(availableSheets);
      } on Object catch (_) {
        // ignore listing failure; parsing below will surface errors.
      }
      final sheetName = argResults['sheet-name'] as String?;
      final descriptionHeader = argResults.wasParsed('description-header')
          ? (argResults['description-header'] as String?)
          : null;
      LocalizationSheet sheet;
      try {
        sheet = parser.parse(
          bytes,
          sheetName: sheetName,
          descriptionHeader: descriptionHeader,
        );
        // Log locales present in the selected sheet.
        final effectiveSheetName =
            sheetName ??
            (availableSheets.isNotEmpty ? availableSheets.first : '(unknown)');
        effectiveLogger.infoSheetLocales(effectiveSheetName, sheet.locales);
      } on SheetNotFoundException catch (e) {
        final available = e.availableSheets.join(', ');
        final msg =
            'Specified sheet "${e.requestedSheet}" not found. '
            'Available sheets: $available';
        emitError(msg);

        return 64;
      }
      final userProvidedDefault = argResults.wasParsed('default-locale');
      String defaultLocale;
      if (userProvidedDefault) {
        final requested = argResults['default-locale'] as String?;
        if (requested == null || !sheet.locales.contains(requested)) {
          final localesList = sheet.locales.join(', ');
          final message =
              'Specified default-locale "${requested ?? ''}" not found '
              'in the sheet locales: $localesList';
          emitError(message);
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
      effectiveLogger.infoDefaultLocale(defaultLocale);

      await exporter.export(sheet, outDir, defaultLocale: defaultLocale);
      effectiveLogger.infoResult(format, outDir);
      return 0;
    } on Exception catch (e) {
      final msg = 'An error occurred: $e';
      emitError(msg);
      return 1;
    }
  }
}
