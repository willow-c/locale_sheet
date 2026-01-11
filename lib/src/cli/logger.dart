import 'dart:io';

/// CLI やライブラリのメッセージ出力に使う簡易的なロガーのインターフェース。
abstract class Logger {
  /// Emit an informational message.
  void info(String message);

  /// Emit an error message.
  void error(String message);

  /// Emit the parsed CLI options in a structured form.
  void infoOptions(Map<String, Object?> options);

  /// Emit the list of available sheet names found in the workbook.
  void infoAvailableSheets(List<String> sheets);

  /// Emit the locales present in the selected sheet.
  void infoSheetLocales(String sheetName, List<String> locales);

  /// Emit the default locale chosen by the command.
  void infoDefaultLocale(String locale);

  /// Emit a final result message describing exported files.
  ///
  /// `format` is the chosen exporter format (e.g. "arb") and `outDir` is
  /// the directory the files were written to.
  void infoResult(String format, String outDir);

  /// Emit a final result message for errors.
  ///
  /// The `message` should describe the error in human-readable form.
  void infoErrorResult(String message);
}

/// デフォルトの簡易ロガー。標準出力/標準エラーにメッセージを出力します。
class SimpleLogger implements Logger {
  /// Enable or disable ANSI color sequences.
  SimpleLogger({this.color = true});

  /// Whether ANSI color sequences are enabled for output.
  ///
  /// When `true`, messages such as errors and headings will be wrapped with
  /// ANSI color codes. Disable for non-TTY output or when colors are not
  /// desired.
  final bool color;

  static const _red = '\x1B[31m';
  static const _green = '\x1B[32m';
  static const _yellow = '\x1B[33m';
  static const _magenta = '\x1B[35m';
  static const _cyan = '\x1B[36m';
  static const _reset = '\x1B[0m';

  String _c(String code, String s) => color ? '$code$s$_reset' : s;

  /// Writes an informational message to stdout.
  @override
  void info(String message) => stdout.writeln(message);

  /// Writes an error message to stderr.
  @override
  void error(String message) => stderr.writeln(_c(_red, 'ERROR: $message'));

  @override
  void infoOptions(Map<String, Object?> options) {
    stdout.writeln(_c(_cyan, 'Options:'));
    options.forEach((k, v) {
      final val = v ?? '';
      final displayVal = v != null ? _c(_yellow, val.toString()) : val;
      stdout.writeln('  $k: $displayVal');
    });
  }

  @override
  void infoAvailableSheets(List<String> sheets) {
    stdout.writeln(
      '${_c(_cyan, 'Input workbook:')} (sheets: ${sheets.length})',
    );
    for (final s in sheets) {
      stdout.writeln('  - ${_c(_magenta, s)}');
    }
  }

  @override
  void infoSheetLocales(String sheetName, List<String> locales) {
    stdout
      ..writeln('${_c(_cyan, 'Selected sheet:')} ${_c(_magenta, sheetName)}')
      ..writeln('${_c(_cyan, 'Locales:')} (count: ${locales.length})');
    for (final l in locales) {
      stdout.writeln('  - ${_c(_magenta, l)}');
    }
  }

  @override
  void infoDefaultLocale(String locale) {
    stdout.writeln(
      '${_c(_cyan, 'Default locale:')} ${_c(_magenta, locale)}',
    );
  }

  @override
  void infoResult(String format, String outDir) {
    final rest = '"$format" format successfully written to $outDir.';
    stdout.writeln(
      '${_c(_cyan, 'Result:')} ${_c(_green, 'Success - $rest')}',
    );
  }

  @override
  void infoErrorResult(String message) {
    stderr.writeln(
      '${_c(_cyan, 'Result:')} ${_c(_red, 'Error - $message')}',
    );
  }
}
