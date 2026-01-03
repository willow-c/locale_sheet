import 'package:locale_sheet/locale_sheet.dart';
import 'package:test/test.dart';

void main() {
  /// LocalizationBundleの基本動作（生成・Map変換・コピー・等価性）を検証
  /// Arrange-Act-Assertパターン
  test('LocalizationBundle behaviors', () {
    // Arrange
    final bundle = LocalizationBundle('en', {
      'hello': 'Hello',
      'bye': 'Goodbye',
    });
    // Act & Assert
    expect(bundle['hello'], 'Hello');
    expect(bundle['missing'], isNull);

    final map = bundle.toMap();
    expect(map['hello'], 'Hello');

    final restored = LocalizationBundle.fromMap('en', map);
    expect(restored.locale, 'en');
    expect(restored['bye'], 'Goodbye');

    final copy = bundle.copyWith(entries: {'x': 'y'});
    expect(copy.locale, 'en');
    expect(copy['x'], 'y');

    final a = LocalizationBundle('en', {'k': 'v'});
    final b = LocalizationBundle('en', {'k': 'v'});
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  /// LocalizationBundleの等価性・hashCodeの境界値を検証
  /// Arrange-Act-Assertパターン
  test('LocalizationBundle equality and hashCode edge', () {
    // Arrange & Act & Assert
    final a = LocalizationBundle('en', {});
    final b = LocalizationBundle('en', {});
    final c = LocalizationBundle('en', {'k': 'v'});
    expect(a, equals(b));
    expect(a == c, isFalse);
    expect(a.hashCode, equals(b.hashCode));
  });

  /// fromMapでnullや非文字列値があっても安全に生成できることを検証
  /// Arrange-Act-Assertパターン
  test('LocalizationBundle fromMap with null/invalid values', () {
    // Arrange & Act & Assert
    final m = {'hello': null, 'bye': 123};
    final b = LocalizationBundle.fromMap('en', m);
    expect(b['hello'], isNull);
    expect(b['bye'], '123');
  });
}
