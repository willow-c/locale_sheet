import 'dart:io';

import 'package:locale_sheet/src/cli/logger.dart';
import 'package:test/test.dart';

/// `writeln` だけを捕捉する `Stdout` の差し替え。
/// 他のメンバは使わないため `noSuchMethod` に委ねる。
class _CapturingStdout implements Stdout {
  _CapturingStdout(this.lines);

  final List<String> lines;

  @override
  void writeln([Object? object = '']) => lines.add('$object\n');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  /// SimpleLoggerがエラーなく標準出力・標準エラー出力を呼び出せることを検証
  /// Arrange-Act-Assertパターン
  test('SimpleLogger prints without error', () {
    // Arrange
    final _ = SimpleLogger()
      // Act
      ..info('info message')
      ..warn('warning message')
      ..error('error message');
    // Assert: 標準出力内容はここでは検証しない。
    // 呼び出しが例外なく通ることのみ確認する。
  });

  /// warnがカラー無効時にWARNING接頭辞付きで出力されることを検証
  /// Arrange-Act-Assertパターン
  test('SimpleLogger.warn prefixes the message with WARNING', () {
    // Arrange: 標準エラー出力を差し替えて内容を捕捉する
    final captured = <String>[];

    // Act
    IOOverrides.runZoned(
      () => SimpleLogger(color: false).warn('duplicate key "hello" found'),
      stderr: () => _CapturingStdout(captured),
    );

    // Assert: 深刻度はレベルが付与し、呼び出し側の文面には含まれない
    expect(captured, ['WARNING: duplicate key "hello" found\n']);
  });

  test('SimpleLogger extras run without throwing', () {
    final _ = SimpleLogger()
      ..infoOptions({
        'input': 'a.xlsx',
        'format': 'arb',
        'out': '.',
      })
      ..infoAvailableSheets([
        'Sheet1',
        'Sheet2',
      ])
      ..infoSheetLocales(
        'Sheet1',
        ['en', 'ja'],
      );

    // No assertions: just ensure methods run without throwing.
    // This records coverage for the formatter methods.
  });

  test('SimpleLogger default/result/error run without throwing', () {
    final _ = SimpleLogger()
      ..infoDefaultLocale('ja')
      ..infoResult('arb', './lib/l10n')
      ..infoErrorResult('something failed');
  });
}
