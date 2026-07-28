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

    _warnIfTreatOptionHasNoEffect(argResults, effectiveLogger);
    _logHeaderAndOptions(
      argResults,
      effectiveLogger,
      inputPath,
      format,
      outDir,
    );

    final exporter = exporters[format];
    if (exporter == null) {
      _emitError('Unsupported format: $format', effectiveLogger);
      return 64;
    }

    try {
      final bytes = await File(inputPath).readAsBytes();
      final prepared = _prepareSheet(argResults, bytes, effectiveLogger);
      if (prepared.exitCode != null) return prepared.exitCode!;
      final sheet = prepared.sheet!;

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
      _emitError('An error occurred: $e', effectiveLogger);
      return 1;
    }
  }

  /// 縮小した `ArgParser` から得た [ArgResults] でも安全に参照するための判定。
  ///
  /// 未定義のオプションを `ArgResults` から読むと例外になる。テストなどでは
  /// 一部のオプションだけを定義したパーサを使うため、参照前に定義の有無を
  /// 確認する。例外を握り潰す実装だと、オプション名の綴り間違いのような
  /// 本当の誤りまで隠れてしまう。
  bool _isDefined(ArgResults argResults, String name) =>
      argResults.options.contains(name);

  bool _wasParsed(ArgResults argResults, String name) =>
      _isDefined(argResults, name) && argResults.wasParsed(name);

  T? _optionOrNull<T>(ArgResults argResults, String name) =>
      _isDefined(argResults, name) ? argResults[name] as T? : null;

  /// 自動検出を有効にせず未定義時の扱いだけを指定した場合に警告する。
  void _warnIfTreatOptionHasNoEffect(
    ArgResults argResults,
    Logger effectiveLogger,
  ) {
    final treatOption = _wasParsed(argResults, 'treat-undefined-placeholders')
        ? _optionOrNull<String>(argResults, 'treat-undefined-placeholders')
        : null;
    final autoDetect =
        _optionOrNull<bool>(argResults, 'auto-detect-placeholders') ?? false;
    if (treatOption != null && !autoDetect) {
      effectiveLogger.warn(
        '--treat-undefined-placeholders was provided but '
        '--auto-detect-placeholders is not set; treat option will be ignored.',
      );
    }
  }

  /// シートを解析し、その結果を利用者に報告する。
  ///
  /// `exitCode` が非 null のとき、呼び出し側はその値で終了する。
  /// それ以外の場合は `sheet` に解析結果が入る。
  ({LocalizationSheet? sheet, int? exitCode}) _prepareSheet(
    ArgResults argResults,
    Uint8List bytes,
    Logger effectiveLogger,
  ) {
    final descriptionHeader = _wasParsed(argResults, 'description-header')
        ? _optionOrNull<String>(argResults, 'description-header')
        : null;
    final requestedLocales = _wasParsed(argResults, 'locales')
        ? _optionOrNull<List<String>>(argResults, 'locales')
        : null;

    ParsedWorkbook parsed;
    try {
      parsed = parser.parseWorkbook(
        bytes,
        sheetName: _optionOrNull<String>(argResults, 'sheet-name'),
        descriptionHeader: descriptionHeader,
        locales: requestedLocales,
      );
    } on SheetNotFoundException catch (e) {
      final available = e.availableSheets.join(', ');
      _emitError(
        'Specified sheet "${e.requestedSheet}" not found. '
        'Available sheets: $available',
        effectiveLogger,
      );
      return (sheet: null, exitCode: 64);
    }

    effectiveLogger.infoAvailableSheets(parsed.availableSheets);
    final effectiveSheetName = parsed.sheetName;
    var sheet = parsed.sheet;

    // Duplicate keys parse successfully but are silently overwritten on
    // export (per locale, last non-empty cell wins), which can mix values
    // from different rows. Warn so the user can fix the sheet.
    for (final key in sheet.duplicateKeys) {
      effectiveLogger.warn(
        'duplicate key "$key" found; later rows override '
        'earlier ones per locale.',
      );
    }

    // 検出と付与はコアの責務。CLI は結果をどう報告するかだけを決める。
    if (_optionOrNull<bool>(argResults, 'auto-detect-placeholders') ?? false) {
      final outcome = _resolvePlaceholders(
        sheet,
        treat:
            _optionOrNull<String>(argResults, 'treat-undefined-placeholders') ??
            'warn',
        defaultType:
            _optionOrNull<String>(argResults, 'placeholder-default-type') ??
            'String',
        effectiveLogger: effectiveLogger,
      );
      sheet = outcome.sheet;
      if (outcome.abort) return (sheet: null, exitCode: 1);
    }

    // どの列がロケールとして扱われ、どの列が外されたかを常に示す。
    // ロケール判定は緩く、`memo` のような一般的な列名も通るため、
    // 採用結果を確認できないと誤った ARB が生成されても気付けない。
    final ignored = sheet.ignoredHeaders.isEmpty
        ? '(none)'
        : sheet.ignoredHeaders.join(', ');
    effectiveLogger
      ..infoSheetLocales(effectiveSheetName, sheet.locales)
      ..info('Ignored columns: $ignored');

    // ロケール列が1つも無いとエクスポータは何も書き出さない。
    // それを成功として報告すると、ヘッダを間違えた利用者が
    // 「出力が空である」ことに気付けないため、エラーとして扱う。
    if (sheet.locales.isEmpty) {
      final hint = sheet.ignoredHeaders.isEmpty
          ? 'The header row has no columns besides "key".'
          : 'None of the remaining columns ($ignored) was treated as a '
                'locale. Use --locales to name them explicitly.';
      _emitError(
        'No locale columns found in sheet "$effectiveSheetName". $hint',
        effectiveLogger,
      );
      return (sheet: null, exitCode: 64);
    }

    return (sheet: sheet, exitCode: null);
  }

  /// プレースホルダを解決し、`--treat-undefined-placeholders` に従って報告する。
  ///
  /// `abort` が `true` のとき、呼び出し側は終了コード `1` で中断する。
  ({LocalizationSheet sheet, bool abort}) _resolvePlaceholders(
    LocalizationSheet sheet, {
    required String treat,
    required String defaultType,
    required Logger effectiveLogger,
  }) {
    final resolution = const PlaceholderResolver().resolve(
      sheet,
      addUndeclared: treat == 'add',
      defaultType: defaultType,
    );

    if (treat == 'error' && resolution.undeclared.isNotEmpty) {
      final first = resolution.undeclared.first;
      _emitError(
        'Undefined placeholder detected: '
        'key=${first.key}, locale=${first.locale}, '
        'placeholder={${first.name}}',
        effectiveLogger,
      );
      return (sheet: resolution.sheet, abort: true);
    }

    for (final finding in resolution.undeclared) {
      if (treat == 'warn') {
        effectiveLogger.warn(
          'key=${finding.key}, locale=${finding.locale}, '
          'placeholder={${finding.name}} not declared',
        );
      } else if (treat == 'add') {
        effectiveLogger.info(
          'auto-added placeholder: '
          'key=${finding.key}, placeholder={${finding.name}}',
        );
      }
    }

    return (sheet: resolution.sheet, abort: false);
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
        'sheet-name': _reportedValue<String>(argResults, 'sheet-name'),
        'default-locale': _reportedValue<String>(argResults, 'default-locale'),
        'locales': _reportedValue<List<String>>(argResults, 'locales')?.join(
          ', ',
        ),
        'description-header': _reportedValue<String>(
          argResults,
          'description-header',
        ),
      });
  }

  /// 明示的に指定されたオプションの値。未指定・未定義なら `null`。
  T? _reportedValue<T>(ArgResults argResults, String name) =>
      _wasParsed(argResults, name) ? _optionOrNull<T>(argResults, name) : null;

  String? _determineDefaultLocale(
    ArgResults argResults,
    LocalizationSheet sheet,
    Logger effectiveLogger,
  ) {
    final userProvidedDefault = _wasParsed(argResults, 'default-locale');
    if (userProvidedDefault) {
      final requested = _optionOrNull<String>(argResults, 'default-locale');
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
