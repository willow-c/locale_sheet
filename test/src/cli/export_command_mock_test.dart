import 'package:args/command_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:locale_sheet/src/cli/cli.dart';
import 'package:locale_sheet/src/cli/logger.dart';
import 'package:test/test.dart';

class MockConverter extends Mock {
  Future<void> call(String inputPath, String outDir);
}

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
  setUpAll(() {
    registerFallbackValue('');
  });

  test('ExportCommand calls injected converter', () async {
    // Arrange
    final mockConv = MockConverter();
    when(() => mockConv.call(any(), any())).thenAnswer((_) async {});
    final logger = TestLogger();
    final cmd = ExportCommand(logger: logger, converter: mockConv.call);
    final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);

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
    expect(logger.infos, contains('ARB ファイルを outdir に出力しました'));
    verify(() => mockConv.call('in.xlsx', 'outdir')).called(1);
  });
}
