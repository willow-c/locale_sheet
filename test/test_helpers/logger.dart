import 'package:locale_sheet/src/cli/logger.dart';

/// テスト用の簡易 Logger 実装。
class TestLogger implements Logger {
  final infos = <String>[];
  final errors = <String>[];

  @override
  void info(String message) => infos.add(message);

  @override
  void error(String message) => errors.add(message);

  @override
  void infoOptions(Map<String, Object?> options) {
    final joined = options.entries.map((e) => '${e.key}=${e.value}').join(', ');
    infos.add('Options: $joined');
  }

  @override
  void infoAvailableSheets(List<String> sheets) {
    infos.add('Available sheets: ${sheets.join(', ')}');
  }

  @override
  void infoSheetLocales(String sheetName, List<String> locales) {
    infos.add('Sheet: $sheetName; Locales: ${locales.join(', ')}');
  }

  @override
  void infoDefaultLocale(String locale) => infos.add('Default locale: $locale');

  @override
  void infoResult(String format, String outDir) => infos.add(
    'Result: Success - "$format" format successfully written to $outDir.',
  );

  @override
  void infoErrorResult(String message) => infos.add('Result: Error - $message');
}
