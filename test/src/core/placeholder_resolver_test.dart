import 'package:locale_sheet/locale_sheet.dart';
import 'package:test/test.dart';

void main() {
  LocalizationSheet sheetWith(
    Map<String, String?> translations, {
    List<String> locales = const ['en'],
    Map<String, Placeholder> placeholders = const {},
  }) => LocalizationSheet(
    locales: locales,
    entries: [
      LocalizationEntry('msg', translations, placeholders: placeholders),
    ],
  );

  /// 宣言されていないプレースホルダが検出され、既定では付与されないことを検証
  /// Arrange-Act-Assertパターン
  test('resolve reports undeclared placeholders without adding them', () {
    // Arrange
    final sheet = sheetWith(const {'en': 'You have {count} items.'});

    // Act
    final result = const PlaceholderResolver().resolve(sheet);

    // Assert
    expect(result.undeclared, [
      const PlaceholderFinding(key: 'msg', locale: 'en', name: 'count'),
    ]);
    expect(result.sheet.entries.single.placeholders, isEmpty);
  });

  /// addUndeclaredで検出結果が付与され、typeとsourceが設定されることを検証
  /// Arrange-Act-Assertパターン
  test('resolve adds undeclared placeholders when asked', () {
    // Arrange
    final sheet = sheetWith(const {'en': 'You have {count} items.'});

    // Act
    final result = const PlaceholderResolver().resolve(
      sheet,
      addUndeclared: true,
      defaultType: 'int',
    );

    // Assert
    final added = result.sheet.entries.single.placeholders['count']!;
    expect(added.type, 'int');
    expect(added.source, 'detected');
  });

  /// 入力のシートが書き換えられないことを検証
  /// Arrange-Act-Assertパターン
  test('resolve does not modify the input sheet', () {
    // Arrange
    final sheet = sheetWith(const {'en': 'You have {count} items.'});

    // Act
    final result = const PlaceholderResolver().resolve(
      sheet,
      addUndeclared: true,
    );

    // Assert: 元のシートは空のまま、返されたシートだけが更新される
    expect(sheet.entries.single.placeholders, isEmpty);
    expect(result.sheet.entries.single.placeholders, isNotEmpty);
    expect(identical(result.sheet, sheet), isFalse);
  });

  /// 1つのメッセージに複数ある場合、すべてが蓄積されることを検証
  /// Arrange-Act-Assertパターン
  test('resolve accumulates multiple placeholders in one message', () {
    // Arrange
    final sheet = sheetWith(const {'en': 'Hello {first} and {second}!'});

    // Act
    final result = const PlaceholderResolver().resolve(
      sheet,
      addUndeclared: true,
    );

    // Assert
    expect(result.sheet.entries.single.placeholders.keys, ['first', 'second']);
  });

  /// 宣言済みのプレースホルダは検出結果に含まれないことを検証
  /// Arrange-Act-Assertパターン
  test('resolve skips placeholders that are already declared', () {
    // Arrange
    final sheet = sheetWith(
      const {'en': 'You have {count} items.'},
      placeholders: const {'count': Placeholder(type: 'int')},
    );

    // Act
    final result = const PlaceholderResolver().resolve(sheet);

    // Assert
    expect(result.undeclared, isEmpty);
  });

  /// 付与しない場合、同じプレースホルダがロケールごとに報告されることを検証
  /// Arrange-Act-Assertパターン
  test('resolve reports the same placeholder once per locale', () {
    // Arrange: en と ja の両方に {count} がある
    final sheet = sheetWith(
      const {'en': 'You have {count} items.', 'ja': '{count}件あります'},
      locales: const ['en', 'ja'],
    );

    // Act
    final result = const PlaceholderResolver().resolve(sheet);

    // Assert: 未宣言のままなので両ロケールで報告される
    expect(result.undeclared.map((f) => f.locale), ['en', 'ja']);
  });

  /// 付与する場合は最初のロケールで宣言済みになり、1度だけ報告されることを検証
  /// Arrange-Act-Assertパターン
  test('resolve reports an added placeholder only once', () {
    // Arrange
    final sheet = sheetWith(
      const {'en': 'You have {count} items.', 'ja': '{count}件あります'},
      locales: const ['en', 'ja'],
    );

    // Act
    final result = const PlaceholderResolver().resolve(
      sheet,
      addUndeclared: true,
    );

    // Assert
    expect(result.undeclared.length, 1);
    expect(result.undeclared.single.locale, 'en');
  });

  /// 翻訳が無いロケールは走査対象外であることを検証
  /// Arrange-Act-Assertパターン
  test('resolve skips locales without a translation', () {
    // Arrange
    final sheet = sheetWith(
      const {'en': 'You have {count} items.', 'ja': null},
      locales: const ['en', 'ja'],
    );

    // Act
    final result = const PlaceholderResolver().resolve(sheet);

    // Assert
    expect(result.undeclared.single.locale, 'en');
  });

  /// ignoredHeadersなどシートの他の情報が保持されることを検証
  /// Arrange-Act-Assertパターン
  test('resolve preserves locales and ignored headers', () {
    // Arrange
    final sheet = LocalizationSheet(
      locales: const ['en'],
      entries: [
        LocalizationEntry('msg', const {'en': 'hi {name}'}),
      ],
      ignoredHeaders: const ['memo'],
    );

    // Act
    final result = const PlaceholderResolver().resolve(
      sheet,
      addUndeclared: true,
    );

    // Assert
    expect(result.sheet.locales, ['en']);
    expect(result.sheet.ignoredHeaders, ['memo']);
  });

  /// PlaceholderFindingが値で等価比較できることを検証
  /// Arrange-Act-Assertパターン
  test('PlaceholderFinding compares by value', () {
    // Arrange
    const a = PlaceholderFinding(key: 'k', locale: 'en', name: 'n');
    const b = PlaceholderFinding(key: 'k', locale: 'en', name: 'n');
    const c = PlaceholderFinding(key: 'k', locale: 'ja', name: 'n');

    // Act & Assert
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a == c, isFalse);
    expect(a.toString(), contains('name: n'));
  });
}
