import 'package:locale_sheet/locale_sheet.dart';
import 'package:test/test.dart';

void main() {
  /// LocalizationEntryの基本動作（生成・コピー・Map変換・等価性）を検証
  /// Arrange-Act-Assertパターン
  test('LocalizationEntry basic behaviors', () {
    // Arrange
    final e = LocalizationEntry('hello', {
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

    final eA = LocalizationEntry('k', {'a': '1'});
    final eB = LocalizationEntry('k', {'a': '1'});
    expect(eA, equals(eB));
    expect(eA.hashCode, equals(eB.hashCode));
  });

  /// fromMapで不正・欠損フィールドがあっても安全に生成できることを検証
  /// Arrange-Act-Assertパターン
  test('LocalizationEntry fromMap with missing/invalid fields', () {
    // Arrange & Act & Assert
    // missing translations
    final m1 = {'key': 'k'};
    final e1 = LocalizationEntry.fromMap(m1);
    expect(e1.key, 'k');
    expect(e1.translations, isEmpty);

    // null translations
    final m2 = {'key': 'k', 'translations': null};
    final e2 = LocalizationEntry.fromMap(m2);
    expect(e2.translations, isEmpty);

    // non-string values
    final m3 = {
      'key': 'k',
      'translations': {'en': 123, 'ja': null},
    };
    final e3 = LocalizationEntry.fromMap(m3);
    expect(e3.translations['en'], '123');
    expect(e3.translations['ja'], isNull);
  });

  /// LocalizationEntryの等価性・hashCodeの境界値を検証
  /// Arrange-Act-Assertパターン
  test('LocalizationEntry equality and hashCode edge', () {
    // Arrange & Act & Assert
    final a = LocalizationEntry('k', {'en': 'v'});
    final b = LocalizationEntry('k', {'en': 'v'});
    final c = LocalizationEntry('k', {'en': 'x'});
    expect(a, equals(b));
    expect(a == c, isFalse);
    expect(a.hashCode, equals(b.hashCode));
  });
}
