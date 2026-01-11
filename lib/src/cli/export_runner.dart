import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';

import 'package:locale_sheet/locale_sheet.dart';
import 'package:locale_sheet/src/cli/logger.dart';

/// Encapsulates the core export flow so the `ExportCommand` can remain thin.
class ExportRunner {
  /// Creates an [ExportRunner].
  ///
  /// The runner performs the export flow using the provided [logger],
  /// [parser], and available [exporters].
  ExportRunner({
    required this.logger,
    required this.parser,
    required this.exporters,
  });

  /// Logger used to emit user-facing messages.
  final Logger logger;

  /// Parser used to read Excel bytes into an internal sheet model.
  final ExcelParser parser;

  /// Map of available exporters keyed by format name.
  final Map<String, LocalizationExporter> exporters;

  /// Execute the export flow using provided command-line [argResults].
  ///
  /// Returns an exit code suitable for use as a process exit value.
  Future<int> run(ArgResults argResults) async {
    final inputPath = argResults['input'] as String;
    final format = argResults['format'] as String;
    final outDir = argResults['out'] as String;

    final effectiveLogger = _buildEffectiveLogger(argResults);

    _logHeaderAndOptions(
      argResults,
      effectiveLogger,
      inputPath,
      format,
      outDir,
    );

    final exporter = exporters[format];
    if (exporter == null) {
      final msg = 'Unsupported format: $format';
      _emitError(msg, effectiveLogger);
      return 64;
    }

    try {
      final bytes = await File(inputPath).readAsBytes();

      final sheetListResult = _listAvailableSheets(
        bytes,
        parser,
        effectiveLogger,
      );

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
        final effectiveSheetName =
            sheetName ?? _determineEffectiveSheetName(sheetListResult);
        effectiveLogger.infoSheetLocales(effectiveSheetName, sheet.locales);
      } on SheetNotFoundException catch (e) {
        final available = e.availableSheets.join(', ');
        final msg =
            'Specified sheet "${e.requestedSheet}" not found. '
            'Available sheets: $available';
        _emitError(msg, effectiveLogger);
        return 64;
      }

      final defaultLocale = _determineDefaultLocale(
        argResults,
        sheet,
        effectiveLogger,
      );
      if (defaultLocale == null) {
        return 64;
      }

      effectiveLogger.infoDefaultLocale(defaultLocale);

      await exporter.export(sheet, outDir, defaultLocale: defaultLocale);
      effectiveLogger.infoResult(format, outDir);
      return 0;
    } on Exception catch (e) {
      final msg = 'An error occurred: $e';
      _emitError(msg, effectiveLogger);
      return 1;
    }
  }

  Logger _buildEffectiveLogger(ArgResults argResults) {
    final useColor = argResults['color'] as bool? ?? true;
    return (logger is SimpleLogger) ? SimpleLogger(color: useColor) : logger;
  }

  void _emitError(String msg, Logger effectiveLogger) {
    if (identical(logger, effectiveLogger)) {
      logger.error(msg);
      return;
    }
    if (logger is SimpleLogger && effectiveLogger is SimpleLogger) {
      effectiveLogger.infoErrorResult(msg);
      return;
    }
    logger.error(msg);
    effectiveLogger.infoErrorResult(msg);
  }

  void _logHeaderAndOptions(
    ArgResults argResults,
    Logger effectiveLogger,
    String inputPath,
    String format,
    String outDir,
  ) {
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
  }

  /// Result of attempting to list available sheets.
  ///
  /// Contains the list of sheet names and a flag indicating whether
  /// the operation succeeded or failed.
  ({List<String> sheets, bool failed}) _listAvailableSheets(
    Uint8List bytes,
    ExcelParser parser,
    Logger effectiveLogger,
  ) {
    try {
      final sheets = parser.getSheetNames(bytes);
      effectiveLogger.infoAvailableSheets(sheets);
      return (sheets: sheets, failed: false);
    } on Object catch (_) {
      return (sheets: <String>[], failed: true);
    }
  }

  /// Determine the effective sheet name for logging purposes.
  ///
  /// Returns a descriptive string based on the result of listing sheets:
  /// - If sheets were listed successfully and at least one exists,
  ///   returns the first sheet name.
  /// - If sheets were listed successfully but none exist,
  ///   returns '(workbook has no sheets)'.
  /// - If listing sheets failed,
  ///   returns '(failed to list sheets)'.
  String _determineEffectiveSheetName(
    ({List<String> sheets, bool failed}) sheetListResult,
  ) {
    if (sheetListResult.failed) {
      return '(failed to list sheets)';
    }
    if (sheetListResult.sheets.isEmpty) {
      return '(workbook has no sheets)';
    }
    return sheetListResult.sheets.first;
  }

  String? _determineDefaultLocale(
    ArgResults argResults,
    LocalizationSheet sheet,
    Logger effectiveLogger,
  ) {
    final userProvidedDefault = argResults.wasParsed('default-locale');
    if (userProvidedDefault) {
      final requested = argResults['default-locale'] as String?;
      if (requested == null || !sheet.locales.contains(requested)) {
        final localesList = sheet.locales.join(', ');
        final message =
            'Specified default-locale "${requested ?? ''}" not found in the '
            'sheet locales: $localesList';
        _emitError(message, effectiveLogger);
        return null;
      }
      return requested;
    }

    if (sheet.locales.contains('en')) {
      return 'en';
    } else if (sheet.locales.isNotEmpty) {
      return sheet.locales.first;
    } else {
      return 'en';
    }
  }
}
