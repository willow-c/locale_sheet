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
}

void main() {
  group('ExportCommand', () {
    late TestLogger logger;
    late CommandRunner<int> runner;

    setUp(() {
      logger = TestLogger();
      final cmd = ExportCommand(logger: logger);
      runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);
    });

    test('run() handles argResults == null gracefully', () async {
      // Arrange
      final cmd = ExportCommand(logger: logger);
      // Act
      // Directly call run() to simulate null argResults, which is a scenario
      // the command should be resilient against.
      // ignore: invalid_use_of_protected_member
      final result = await cmd.run();
      // Assert
      expect(result, 64);
      expect(logger.errors.first, contains('引数の解析に失敗しました'));
    });

    test('missing --input throws ArgumentError', () async {
      // Act & Assert
      try {
        await runner.run(['export']);
        fail('should have thrown ArgumentError');
      } on ArgumentError catch (e) {
        expect(e.message, 'Option input is mandatory.');
      }
    });

    test('unsupported format throws UsageException', () async {
      // Act & Assert
      try {
        await runner.run([
          'export',
          '--input',
          'dummy.xlsx',
          '--format',
          'unsupported',
        ]);
        fail('should have thrown UsageException');
      } on UsageException catch (e) {
        expect(
          e.message,
          contains(
            '"unsupported" is not an allowed value for option "--format".',
          ),
        );
      }
    });

    test('non-existent input file returns 1 and logs error', () async {
      // Arrange
      const nonExistentFile = 'path/to/non_existent_file.xlsx';

      // Act
      final result = await runner.run(['export', '--input', nonExistentFile]);

      // Assert
      expect(result, 1);
      expect(logger.errors, isNotEmpty);
      expect(logger.errors.first, contains('エラーが発生しました'));
    });
  });
}
