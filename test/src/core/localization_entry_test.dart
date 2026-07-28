import 'package:locale_sheet/locale_sheet.dart';
import 'package:test/test.dart';

void main() {
  /// LocalizationEntryの基本動作（生成・コピー・Map変換・等価性）を検証
  /// Arrange-Act-Assertパターン
  test('LocalizationEntry basic behaviors', () {
    // Arrange
    final e = LocalizationEntry('hello', const {
      'en': 'Hello',
      'ja': 'こんにちは',
    }, description: 'greeting');
    // Act & Assert
    expect(e.translationFor('en'), 'Hello');
    expect(e.translationFor('ja'), 'こんにちは');
    expect(e.translationFor('xx'), isNull);

    final e2 = e.copyWith(key: 'hi');
    expect(e2.key, 'hi');
    expect(e2.description, 'greeting');

    final map = e.toMap();
    final restored = LocalizationEntry.fromMap(Map<String, dynamic>.from(map));
    expect(restored.key, e.key);
    expect(restored.description, e.description);
    expect(restored.translations['en'], 'Hello');

    final eA = LocalizationEntry('k', const {'a': '1'});
    final eB = LocalizationEntry('k', const {'a': '1'});
    expect(eA, equals(eB));
    expect(eA.hashCode, equals(eB.hashCode));
  });

  /// fromMapで不正・欠損フィールドがあっても安全に生成できることを検証
  /// Arrange-Act-Assertパターン
  test('LocalizationEntry fromMap with missing/invalid fields', () {
    // Arrange & Act & Assert
    // missing translations
    const m1 = {'key': 'k'};
    final e1 = LocalizationEntry.fromMap(m1);
    expect(e1.key, 'k');
    expect(e1.translations, isEmpty);

    // null translations
    const m2 = {'key': 'k', 'translations': null};
    final e2 = LocalizationEntry.fromMap(m2);
    expect(e2.translations, isEmpty);

    // non-string values
    const m3 = {
      'key': 'k',
      'translations': {'en': 123, 'ja': null},
    };
    final e3 = LocalizationEntry.fromMap(m3);
    expect(e3.translations['en'], '123');
    expect(e3.translations['ja'], isNull);
  });

  /// プレースホルダを含むエントリがtoMap/fromMapで往復できることと、
  /// placeholders内の不正な要素が無視されることを検証
  /// Arrange-Act-Assertパターン
  test('LocalizationEntry round-trips placeholders through toMap/fromMap', () {
    // Arrange
    final original = LocalizationEntry(
      'items_count',
      const {'en': 'You have {count} items.'},
      description: 'item counter',
      placeholders: const {
        'count': Placeholder(type: 'int', example: '3', source: 'declared'),
      },
    );

    // Act
    final restored = LocalizationEntry.fromMap(
      Map<String, dynamic>.from(original.toMap()),
    );

    // Assert: プレースホルダの各フィールドが保持される
    expect(restored.placeholders.keys, ['count']);
    final ph = restored.placeholders['count']!;
    expect(ph.type, 'int');
    expect(ph.example, '3');
    expect(ph.source, 'declared');
    expect(restored, equals(original));

    // placeholders の値がMapでない場合はそのエントリを無視する
    const invalid = {
      'key': 'k',
      'placeholders': {'bad': 'not-a-map'},
    };
    final fromInvalid = LocalizationEntry.fromMap(invalid);
    expect(fromInvalid.placeholders, isEmpty);
  });

  /// LocalizationEntryの等価性・hashCodeの境界値を検証
  /// Arrange-Act-Assertパターン
  test('LocalizationEntry equality and hashCode edge', () {
    // Arrange & Act & Assert
    final a = LocalizationEntry('k', const {'en': 'v'});
    final b = LocalizationEntry('k', const {'en': 'v'});
    final c = LocalizationEntry('k', const {'en': 'x'});
    expect(a, equals(b));
    expect(a == c, isFalse);
    expect(a.hashCode, equals(b.hashCode));
  });

  /// プレースホルダを持つエントリ同士でも、内容が同じなら等価と判定され
  /// hashCodeも一致することを検証（Placeholderの値比較が使われること）
  /// Arrange-Act-Assertパターン
  test('LocalizationEntry equality accounts for placeholder values', () {
    // Arrange: 同じ内容のプレースホルダを持つ別インスタンス
    final a = LocalizationEntry(
      'k',
      const {'en': 'v {n}'},
      placeholders: const {'n': Placeholder(type: 'int')},
    );
    final b = LocalizationEntry(
      'k',
      const {'en': 'v {n}'},
      placeholders: const {'n': Placeholder(type: 'int')},
    );
    final differentType = LocalizationEntry(
      'k',
      const {'en': 'v {n}'},
      placeholders: const {'n': Placeholder(type: 'String')},
    );
    final noPlaceholder = LocalizationEntry('k', const {'en': 'v {n}'});

    // Act & Assert
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a == differentType, isFalse);
    expect(a == noPlaceholder, isFalse);
  });
}
