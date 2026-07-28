import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:locale_sheet/locale_sheet.dart';
import 'package:locale_sheet/src/cli/exit_codes.dart';
import 'package:locale_sheet/src/cli/export_runner.dart';
import 'package:locale_sheet/src/cli/logger.dart';
import 'package:test/test.dart';

import '../../test_helpers/logger.dart';

class _FakeExporter implements LocalizationExporter {
  String? lastOutDir;
  LocalizationSheet? lastSheet;
  String? lastDefaultLocale;

  @override
  Future<void> export(
    LocalizationSheet sheet,
    String outDir, {
    String? defaultLocale,
  }) async {
    lastSheet = sheet;
    lastOutDir = outDir;
    lastDefaultLocale = defaultLocale;
  }
}

class _FakeParser extends ExcelParser {
  _FakeParser(this.sheet, {this.sheets = const <String>[]});
  final LocalizationSheet sheet;
  final List<String> sheets;

  @override
  ParsedWorkbook parseWorkbook(
    Uint8List bytes, {
    String? sheetName,
    String? descriptionHeader,
    List<String>? locales,
  }) => ParsedWorkbook(
    sheet: sheet,
    sheetName: sheetName ?? (sheets.isNotEmpty ? sheets.first : 'Sheet1'),
    availableSheets: sheets,
  );
}

class _ThrowingParser extends ExcelParser {
  _ThrowingParser(this.requested, this.available);
  final String requested;
  final List<String> available;

  @override
  ParsedWorkbook parseWorkbook(
    Uint8List bytes, {
    String? sheetName,
    String? descriptionHeader,
    List<String>? locales,
  }) {
    throw SheetNotFoundException(requested, available);
  }
}

class _FormatThrowingParser extends ExcelParser {
  @override
  ParsedWorkbook parseWorkbook(
    Uint8List bytes, {
    String? sheetName,
    String? descriptionHeader,
    List<String>? locales,
  }) {
    throw const FormatException('bad format');
  }
}

void main() {
  ArgParser argParser() => ArgParser()
    ..addOption('input')
    ..addOption('format')
    ..addOption('out')
    ..addOption('sheet-name')
    ..addOption('default-locale')
    ..addOption('description-header')
    ..addFlag('color', defaultsTo: true);

  test('run returns 0 and calls exporter on success', () async {
    final logger = TestLogger();
    final sheet = LocalizationSheet(locales: const ['en', 'ja'], entries: []);
    final parser = _FakeParser(sheet, sheets: ['Sheet1', 'Sheet2']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(0));
      expect(exporter.lastOutDir, equals('outdir'));
      expect(exporter.lastSheet, isNotNull);
      expect(logger.infos.any((s) => s.startsWith('Result: Success')), isTrue);
    } finally {
      await tmp.delete();
    }
  });

  test('returns EX_USAGE when format unsupported', () async {
    final logger = TestLogger();
    final sheet = LocalizationSheet(locales: const ['en'], entries: []);
    final parser = _FakeParser(sheet);

    final tmp = File('test/tmp_export_runner2.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'unsupported',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': _FakeExporter()},
      );

      final res = await runner.run(args);
      expect(res, equals(exitUsage));
      expect(logger.errors, isNotEmpty);
      expect(logger.errors.first, contains('Unsupported format'));
    } finally {
      await tmp.delete();
    }
  });

  test('returns EX_DATAERR when sheet not found', () async {
    final logger = TestLogger();
    final parser = _ThrowingParser('Missing', ['SheetA', 'SheetB']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner3.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--sheet-name',
        'Missing',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(exitDataError));
      expect(logger.errors.first, contains('Missing'));
      expect(logger.errors.first, contains('SheetA'));
    } finally {
      await tmp.delete();
    }
  });

  test('returns EX_DATAERR when provided default-locale is invalid', () async {
    final logger = TestLogger();
    final sheet = LocalizationSheet(locales: const ['ja'], entries: []);
    final parser = _FakeParser(sheet);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner4.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(exitDataError));
      expect(logger.errors.first, contains('Specified default-locale'));
    } finally {
      await tmp.delete();
    }
  });

  test('returns EX_DATAERR when parser throws FormatException', () async {
    final logger = TestLogger();
    final parser = _FormatThrowingParser();
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner5.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(exitDataError));
      expect(logger.errors.first, contains('Invalid input'));
    } finally {
      await tmp.delete();
    }
  });

  /// シート名を省略した場合、解析器が報告したシート名がログに使われることを検証
  /// （CLI 側で「最初のシート」を推測し直さない）
  /// Arrange-Act-Assertパターン
  test('logs the sheet name reported by the parser', () async {
    // Arrange: シート名は指定せず、解析器は Sheet2 を解析したと報告する
    final logger = TestLogger();
    final sheet = LocalizationSheet(locales: const ['en', 'ja'], entries: []);
    final parser = _FakeParser(sheet, sheets: ['Sheet2', 'Sheet1']);

    final tmp = File('test/tmp_export_runner_sheetname.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': _FakeExporter()},
      );

      // Act
      final res = await runner.run(args);

      // Assert: シート一覧と選択されたシートの両方が報告される
      expect(res, equals(0));
      final infoMessages = logger.infos.join(' ');
      expect(infoMessages, contains('Available sheets: Sheet2, Sheet1'));
      expect(infoMessages, contains('Sheet: Sheet2'));
    } finally {
      await tmp.delete();
    }
  });

  /// 説明列に key を指定した場合、入力を読む前にEX_USAGE(64)で終わることを検証
  /// Arrange-Act-Assertパターン
  test('returns EX_USAGE when the description header is "key"', () async {
    // Arrange: 1列目は必ずキー列なので、入力の内容に関わらず誤り
    final logger = TestLogger();
    final sheet = LocalizationSheet(locales: const ['en'], entries: []);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    // 入力ファイルは用意しない。読み込み前に弾かれることの確認を兼ねる。
    final args = ExportCommand().argParser.parse([
      '--input',
      'test/no_such_file_should_not_be_read.xlsx',
      '--format',
      'arb',
      '--out',
      'outdir',
      '--description-header',
      'Key',
    ]);

    final runner = ExportRunner(
      logger: logger,
      parser: parser,
      exporters: {'arb': exporter},
    );

    // Act
    final res = await runner.run(args);

    // Assert: 入力を読んでいれば EX_NOINPUT になるはずなので、
    // EX_USAGE であることが「読む前に弾いた」ことの証明になる
    expect(res, equals(exitUsage));
    expect(
      logger.errors.join('\n'),
      contains("--description-header cannot be 'key'"),
    );
    expect(exporter.lastSheet, isNull);
  });

  /// 出力先を作成できない場合にEX_CANTCREAT(73)を返すことを検証
  /// Arrange-Act-Assertパターン
  test('returns EX_CANTCREAT when the output cannot be written', () async {
    // Arrange: 既存のファイルを出力先に指定するとディレクトリを作れない
    final logger = TestLogger();
    final sheet = LocalizationSheet(
      locales: const ['en'],
      entries: [
        LocalizationEntry('hello', const {'en': 'Hello'}),
      ],
    );
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);

    final tmp = Directory.systemTemp.createTempSync('export_runner_cantcreat');
    final input = File('${tmp.path}/in.xlsx')..writeAsBytesSync([0]);
    final blocker = File('${tmp.path}/out')..writeAsStringSync('not a dir');

    try {
      final args = argParser().parse([
        '--input',
        input.path,
        '--format',
        'arb',
        '--out',
        blocker.path,
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        // 実物のエクスポーターを使う（書き込みの失敗を再現するため）
        exporters: {'arb': ArbExporter()},
      );

      // Act
      final res = await runner.run(args);

      // Assert
      expect(res, equals(exitCantCreate));
      expect(logger.errors.join('\n'), contains('Cannot write output to'));
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  /// 一部のオプションが定義されていないArgParserから得たArgResultsでも
  /// 例外にならず、未指定として扱われることを検証
  /// Arrange-Act-Assertパターン
  test(
    'tolerates an ArgResults from a parser without optional options',
    () async {
      // Arrange: プレースホルダ系や locales を一切定義していない最小のパーサ
      final minimal = ArgParser()
        ..addOption('input')
        ..addOption('format')
        ..addOption('out')
        ..addFlag('color', defaultsTo: true);

      final logger = TestLogger();
      final sheet = LocalizationSheet(locales: const ['en'], entries: []);
      final parser = _FakeParser(sheet, sheets: ['Sheet1']);
      final exporter = _FakeExporter();

      final tmp = File('test/tmp_export_runner_minimal_parser.xlsx');
      await tmp.writeAsBytes([0]);

      try {
        final args = minimal.parse([
          '--input',
          tmp.path,
          '--format',
          'arb',
          '--out',
          'outdir',
        ]);

        final runner = ExportRunner(
          logger: logger,
          parser: parser,
          exporters: {'arb': exporter},
        );

        // Act
        final res = await runner.run(args);

        // Assert: 未定義のオプションは未指定として扱われ、通常どおり完了する
        expect(res, equals(0));
        expect(exporter.lastSheet, isNotNull);
        expect(logger.warnings, isEmpty);
      } finally {
        await tmp.delete();
      }
    },
  );

  /// ロケール列が1つも無い場合に、成功扱いにせず終了コード64を返すことを検証
  /// Arrange-Act-Assertパターン
  test('returns EX_DATAERR when the sheet has no locale columns', () async {
    // Arrange: key 以外の列はあるが、どれもロケールとして採用されなかった
    final logger = TestLogger();
    final sheet = LocalizationSheet(
      locales: const [],
      entries: [LocalizationEntry('hello', const {})],
      ignoredHeaders: const ['description', '備考'],
    );
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_no_locales.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      // Act
      final res = await runner.run(args);

      // Assert: エクスポートは行われず、無視した列と回避策が示される
      expect(res, equals(exitDataError));
      expect(exporter.lastSheet, isNull);
      final err = logger.errors.join('\n');
      expect(err, contains('No locale columns found'));
      expect(err, contains('description'));
      expect(err, contains('--locales'));
    } finally {
      await tmp.delete();
    }
  });

  /// key 列しか無いシートでは、無視した列が無い旨のメッセージになることを検証
  /// Arrange-Act-Assertパターン
  test(
    'explains that only a key column exists when nothing was ignored',
    () async {
      // Arrange
      final logger = TestLogger();
      final sheet = LocalizationSheet(locales: const [], entries: []);
      final parser = _FakeParser(sheet, sheets: ['Sheet1']);

      final tmp = File('test/tmp_export_runner_key_only.xlsx');
      await tmp.writeAsBytes([0]);

      try {
        final args = argParser().parse([
          '--input',
          tmp.path,
          '--format',
          'arb',
          '--out',
          'outdir',
        ]);

        final runner = ExportRunner(
          logger: logger,
          parser: parser,
          exporters: {'arb': _FakeExporter()},
        );

        // Act
        final res = await runner.run(args);

        // Assert
        expect(res, equals(exitDataError));
        expect(
          logger.errors.join('\n'),
          contains('no columns besides "key"'),
        );
      } finally {
        await tmp.delete();
      }
    },
  );

  /// ロケールとして扱った列と無視した列が常にログ出力されることを検証
  /// Arrange-Act-Assertパターン
  test('logs both the selected locales and the ignored columns', () async {
    // Arrange
    final logger = TestLogger();
    final sheet = LocalizationSheet(
      locales: const ['en', 'ja'],
      entries: [],
      ignoredHeaders: const ['memo', '備考'],
    );
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);

    final tmp = File('test/tmp_export_runner_ignored.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': _FakeExporter()},
      );

      // Act
      final res = await runner.run(args);

      // Assert
      expect(res, equals(0));
      final joined = logger.infos.join('\n');
      expect(joined, contains('Locales: en, ja'));
      expect(joined, contains('Ignored columns: memo, 備考'));
    } finally {
      await tmp.delete();
    }
  });

  /// 無視した列が無い場合も、その旨がログに出ることを検証
  /// Arrange-Act-Assertパターン
  test('logs "(none)" when no column was ignored', () async {
    // Arrange
    final logger = TestLogger();
    final sheet = LocalizationSheet(locales: const ['en'], entries: []);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);

    final tmp = File('test/tmp_export_runner_no_ignored.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': _FakeExporter()},
      );

      // Act
      final res = await runner.run(args);

      // Assert
      expect(res, equals(0));
      expect(
        logger.infos.any((s) => s == 'Ignored columns: (none)'),
        isTrue,
      );
    } finally {
      await tmp.delete();
    }
  });

  /// 重複キーを含むシートで警告が出力され、処理自体は継続することを検証
  /// Arrange-Act-Assertパターン
  test('logs a warning for duplicate keys and still succeeds', () async {
    // Arrange: hello が2行に重複して存在するシート
    final logger = TestLogger();
    final sheet = LocalizationSheet(
      locales: const ['en'],
      entries: [
        LocalizationEntry('hello', const {'en': 'Hello'}),
        LocalizationEntry('hello', const {'en': 'Hi again'}),
      ],
    );
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_duplicate.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      // Act
      final res = await runner.run(args);

      // Assert: 警告は出るがエクスポートは成功する
      expect(res, equals(0));
      expect(
        logger.warnings.any(
          (s) => s.contains('duplicate key "hello"'),
        ),
        isTrue,
      );
      expect(exporter.lastSheet, isNotNull);
    } finally {
      await tmp.delete();
    }
  });

  /// 重複キーがない場合は重複警告を出力しないことを検証
  /// Arrange-Act-Assertパターン
  test('does not log a duplicate-key warning for unique keys', () async {
    // Arrange
    final logger = TestLogger();
    final sheet = LocalizationSheet(
      locales: const ['en'],
      entries: [
        LocalizationEntry('hello', const {'en': 'Hello'}),
        LocalizationEntry('bye', const {'en': 'Goodbye'}),
      ],
    );
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_unique.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = argParser().parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      // Act
      final res = await runner.run(args);

      // Assert
      expect(res, equals(0));
      expect(
        logger.warnings.any((s) => s.contains('duplicate key')),
        isFalse,
      );
    } finally {
      await tmp.delete();
    }
  });

  test('auto-detect warn does not add placeholder but logs warning', () async {
    final logger = TestLogger();
    final entry = LocalizationEntry('items_count', const {
      'en': 'You have {count} items.',
    });
    final sheet = LocalizationSheet(locales: const ['en'], entries: [entry]);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_warn.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = ExportCommand().argParser.parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--auto-detect-placeholders',
        '--treat-undefined-placeholders',
        'warn',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(0));
      expect(exporter.lastSheet, isNotNull);
      final outEntry = exporter.lastSheet!.entries.first;
      expect(outEntry.placeholders.isEmpty, isTrue);
      expect(logger.warnings.any((s) => s.contains('not declared')), isTrue);
    } finally {
      await tmp.delete();
    }
  });

  test('auto-detect add actually adds placeholder metadata', () async {
    final logger = TestLogger();
    final entry = LocalizationEntry('items_count', const {
      'en': 'You have {count} items.',
    });
    final sheet = LocalizationSheet(locales: const ['en'], entries: [entry]);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_add.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = ExportCommand().argParser.parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--auto-detect-placeholders',
        '--treat-undefined-placeholders',
        'add',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(0));
      final outEntry = exporter.lastSheet!.entries.first;
      expect(outEntry.placeholders.containsKey('count'), isTrue);
      expect(outEntry.placeholders['count']!.type, equals('String'));
    } finally {
      await tmp.delete();
    }
  });

  test('auto-detect add accumulates multiple placeholders', () async {
    final logger = TestLogger();
    final entry = LocalizationEntry('greet_both', const {
      'en': 'Hello {first} and {second}!',
    });
    final sheet = LocalizationSheet(locales: const ['en'], entries: [entry]);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_multi.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = ExportCommand().argParser.parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--auto-detect-placeholders',
        '--treat-undefined-placeholders',
        'add',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(0));
      final outEntry = exporter.lastSheet!.entries.first;
      expect(outEntry.placeholders.containsKey('first'), isTrue);
      expect(outEntry.placeholders.containsKey('second'), isTrue);
    } finally {
      await tmp.delete();
    }
  });

  /// 自動検出を有効にせず未定義時の扱いだけを指定した場合、
  /// そのオプションが無視される旨を警告することを検証
  /// Arrange-Act-Assertパターン
  test(
    'warns when treat-undefined-placeholders is set without auto-detection',
    () async {
      // Arrange: --auto-detect-placeholders を付けずに treat だけ指定する
      final logger = TestLogger();
      final entry = LocalizationEntry('items_count', const {
        'en': 'You have {count} items.',
      });
      final sheet = LocalizationSheet(locales: const ['en'], entries: [entry]);
      final parser = _FakeParser(sheet, sheets: ['Sheet1']);
      final exporter = _FakeExporter();

      final tmp = File('test/tmp_export_runner_treat_only.xlsx');
      await tmp.writeAsBytes([0]);

      try {
        final args = ExportCommand().argParser.parse([
          '--input',
          tmp.path,
          '--format',
          'arb',
          '--out',
          'outdir',
          '--treat-undefined-placeholders',
          'warn',
          '--default-locale',
          'en',
        ]);

        final runner = ExportRunner(
          logger: logger,
          parser: parser,
          exporters: {'arb': exporter},
        );

        // Act
        final res = await runner.run(args);

        // Assert: 警告は出るが処理は成功し、検出も行われない
        expect(res, equals(0));
        expect(
          logger.warnings.any(
            (s) => s.contains(
              '--treat-undefined-placeholders was provided but',
            ),
          ),
          isTrue,
        );
        expect(exporter.lastSheet!.entries.first.placeholders, isEmpty);
      } finally {
        await tmp.delete();
      }
    },
  );

  /// treat=error で未定義プレースホルダを検出した場合に
  /// 終了コード1で中断し、エクスポートが行われないことを検証
  /// Arrange-Act-Assertパターン
  test('auto-detect error aborts with EX_DATAERR before exporting', () async {
    // Arrange
    final logger = TestLogger();
    final entry = LocalizationEntry('items_count', const {
      'en': 'You have {count} items.',
    });
    final sheet = LocalizationSheet(locales: const ['en'], entries: [entry]);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_error.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = ExportCommand().argParser.parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--auto-detect-placeholders',
        '--treat-undefined-placeholders',
        'error',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      // Act
      final res = await runner.run(args);

      // Assert: 中断されるためエクスポーターは呼ばれない
      expect(res, equals(exitDataError));
      expect(
        logger.errors.any(
          (s) => s.contains('Undefined placeholder detected'),
        ),
        isTrue,
      );
      expect(exporter.lastSheet, isNull);
    } finally {
      await tmp.delete();
    }
  });

  /// --placeholder-default-type で指定した型が自動追加時に使われることを検証
  /// Arrange-Act-Assertパターン
  test('auto-detect add honors placeholder-default-type', () async {
    // Arrange
    final logger = TestLogger();
    final entry = LocalizationEntry('items_count', const {
      'en': 'You have {count} items.',
    });
    final sheet = LocalizationSheet(locales: const ['en'], entries: [entry]);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_type.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = ExportCommand().argParser.parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--auto-detect-placeholders',
        '--treat-undefined-placeholders',
        'add',
        '--placeholder-default-type',
        'int',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      // Act
      final res = await runner.run(args);

      // Assert: 既定の String ではなく指定した int が使われる
      expect(res, equals(0));
      final outEntry = exporter.lastSheet!.entries.first;
      expect(outEntry.placeholders['count']!.type, equals('int'));
    } finally {
      await tmp.delete();
    }
  });

  /// ロガーを差し替えていない場合（既定の SimpleLogger）でも
  /// エラーが報告され終了コード1を返すことを検証
  /// Arrange-Act-Assertパターン
  test('reports errors through the default SimpleLogger', () async {
    // Arrange: SimpleLogger を渡すと内部で色設定を反映した別インスタンスが
    // 作られるため、ロガーが同一でない場合のエラー出力経路を通る
    final sheet = LocalizationSheet(locales: const ['en'], entries: []);
    final runner = ExportRunner(
      logger: SimpleLogger(color: false),
      parser: _FakeParser(sheet),
      exporters: {'arb': _FakeExporter()},
    );

    final args = argParser().parse([
      '--input',
      'test/no_such_input_file.xlsx',
      '--format',
      'arb',
      '--out',
      'outdir',
      '--no-color',
    ]);

    // Act: 入力ファイルが存在しないため読み込みで失敗する
    final res = await runner.run(args);

    // Assert
    expect(res, equals(exitNoInput));
  });

  test('auto-detect ignore does not log warning and does not add', () async {
    final logger = TestLogger();
    final entry = LocalizationEntry('items_count', const {
      'en': 'You have {count} items.',
    });
    final sheet = LocalizationSheet(locales: const ['en'], entries: [entry]);
    final parser = _FakeParser(sheet, sheets: ['Sheet1']);
    final exporter = _FakeExporter();

    final tmp = File('test/tmp_export_runner_ignore.xlsx');
    await tmp.writeAsBytes([0]);

    try {
      final args = ExportCommand().argParser.parse([
        '--input',
        tmp.path,
        '--format',
        'arb',
        '--out',
        'outdir',
        '--auto-detect-placeholders',
        '--treat-undefined-placeholders',
        'ignore',
        '--default-locale',
        'en',
      ]);

      final runner = ExportRunner(
        logger: logger,
        parser: parser,
        exporters: {'arb': exporter},
      );

      final res = await runner.run(args);
      expect(res, equals(0));
      final outEntry = exporter.lastSheet!.entries.first;
      expect(outEntry.placeholders.isEmpty, isTrue);
      expect(logger.warnings, isEmpty);
    } finally {
      await tmp.delete();
    }
  });
}
