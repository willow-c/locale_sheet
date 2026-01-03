import 'package:args/command_runner.dart';
import 'package:locale_sheet/src/cli/cli.dart';
import 'package:locale_sheet/src/cli/logger.dart';
import 'package:test/test.dart';

class TestLogger implements Logger {
  final infos = <String>[];
  final errors = <String>[];

  @override
  void info(String message) => infos.add(message);

  @override
  void error(String message) => errors.add(message);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  /// argResultsがnullの場合にエラー終了することを検証（CLIの堅牢性）
  /// Arrange-Act-Assertパターン
  test('run() handles argResults == null gracefully', () async {
    // Arrange
    final logger = TestLogger();
    final cmd = ExportCommand(logger: logger, converter: (i, o) async {});
    // Act
    // argResultsをnullにするために直接run()を呼ぶ
    // 通常はCommandRunner経由だが、テスト用に直接run()を呼ぶことでnullを再現
    // ignore: invalid_use_of_protected_member
    final result = await cmd.run();
    // Assert
    expect(result, 64);
    expect(logger.errors, contains(contains('argResults が null')));
  });

  /// converterが例外を投げた場合にエラー終了し、エラーログが出力されることを検証
  /// Arrange-Act-Assertパターン
  test('converter throws: returns 1 and logs error', () async {
    // Arrange
    final logger = TestLogger();
    final cmd = ExportCommand(
      logger: logger,
      converter: (i, o) async => throw Exception('fail!'),
    );
    final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);
    // Act
    final res = await runner.run(['export', '--input', 'in.xlsx']);
    // Assert
    expect(res, 1);
    expect(logger.errors, isNotEmpty);
    expect(logger.errors.first, contains('処理に失敗'));
  });

  /// 入力ファイル未指定時にエラー終了し、エラーメッセージが出力されることを検証
  /// Arrange-Act-Assertパターン
  test('missing input returns 64 and writes stderr (Japanese)', () async {
    // Arrange
    final logger = TestLogger();
    final cmd = ExportCommand(logger: logger, converter: (i, o) async {});
    final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);
    // Act
    final res = await runner.run(['export']);
    // Assert
    expect(res, 64);
    expect(logger.errors, contains(contains('入力ファイル')));
  });

  /// サポート外のformat指定時にエラー終了し、エラーメッセージが出力されることを検証
  /// Arrange-Act-Assertパターン
  test('unsupported format returns 64 (Japanese)', () async {
    // Arrange
    final logger = TestLogger();
    final cmd = ExportCommand(logger: logger, converter: (i, o) async {});
    final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);
    // Act
    final res = await runner.run([
      'export',
      '--input',
      'in.xlsx',
      '--format',
      'resx',
    ]);
    // Assert
    expect(res, 64);
    expect(logger.errors, contains(contains('サポートされていない')));
  });

  /// 正常系：converterが呼ばれ、0で正常終了し、infoログが出力されることを検証
  /// Arrange-Act-Assertパターン
  test(
    'successful conversion calls converter and returns 0 (Japanese)',
    () async {
      // Arrange
      final logger = TestLogger();
      String? calledIn;
      String? calledOut;
      final cmd = ExportCommand(
        logger: logger,
        converter: (i, o) async {
          calledIn = i;
          calledOut = o;
        },
      );
      final runner = CommandRunner<int>('locale_sheet', 'test')
        ..addCommand(cmd);
      // Act
      final res = await runner.run([
        'export',
        '--input',
        'in.xlsx',
        '--out',
        'outdir',
      ]);
      // Assert
      expect(res, 0);
      expect(calledIn, 'in.xlsx');
      expect(calledOut, 'outdir');
      expect(logger.infos, contains('ARB ファイルを outdir に出力しました'));
    },
  );

  test('converter throws: returns 1 and logs error', () async {
    final logger = TestLogger();
    final cmd = ExportCommand(
      logger: logger,
      converter: (i, o) async => throw Exception('fail!'),
    );
    final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);
    final res = await runner.run(['export', '--input', 'in.xlsx']);
    expect(res, 1);
    expect(logger.errors, isNotEmpty);
    expect(logger.errors.first, contains('処理に失敗'));
  });
}
