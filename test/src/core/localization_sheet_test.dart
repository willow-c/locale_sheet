import 'package:locale_sheet/locale_sheet.dart';
import 'package:test/test.dart';

void main() {
  /// bundleForの正常系・異常系、toBundlesの網羅、空データ時の挙動も検証
  /// Arrange-Act-Assertパターン
  test('bundleFor returns correct bundle and throws on missing locale', () {
    // Arrange
    final entries = [
      LocalizationEntry('hello', {'en': 'Hello', 'ja': 'こんにちは'}),
      LocalizationEntry('bye', {'en': 'Goodbye'}),
    ];
    final sheet = LocalizationSheet(locales: ['en', 'ja'], entries: entries);
    // Act
    final enBundle = sheet.bundleFor('en');
    final jaBundle = sheet.bundleFor('ja');
    // Assert
    expect(enBundle['hello'], 'Hello');
    expect(enBundle['bye'], 'Goodbye');
    expect(jaBundle['hello'], 'こんにちは');
    expect(jaBundle['bye'], isNull); // ja翻訳なし
    // 異常系: 存在しないロケール
    expect(() => sheet.bundleFor('fr'), throwsA(isA<StateError>()));
  });

  /// toBundlesの全ロケール網羅、空データ時の挙動も検証
  /// Arrange-Act-Assertパターン
  test('toBundles returns all locale bundles, handles empty', () {
    // Arrange
    final entries = [
      LocalizationEntry('k', {'en': 'v1', 'ja': 'v2'}),
    ];
    final sheet = LocalizationSheet(locales: ['en', 'ja'], entries: entries);
    // Act
    final bundles = sheet.toBundles();
    // Assert
    expect(bundles.length, 2);
    expect(bundles[0].locale, 'en');
    expect(bundles[1].locale, 'ja');
    expect(bundles[0]['k'], 'v1');
    expect(bundles[1]['k'], 'v2');

    // 空ロケール・空エントリ
    final emptySheet = LocalizationSheet(locales: [], entries: []);
    expect(emptySheet.toBundles(), isEmpty);
  });

  /// LocalizationSheetの基本動作（生成・locale/entry取得・toMap・fromMap）を検証
  /// Arrange-Act-Assertパターン
  test('LocalizationSheet basic behaviors', () {
    // Arrange
    final entries = [
      LocalizationEntry('hello', {'en': 'Hello', 'ja': 'こんにちは'}),
      LocalizationEntry('bye', {'en': 'Goodbye', 'ja': 'さようなら'}),
    ];
    final sheet = LocalizationSheet(locales: ['en', 'ja'], entries: entries);

    // Act & Assert
    expect(sheet.locales, ['en', 'ja']);
    expect(sheet.entries.length, 2);
    expect(sheet.entries[0].key, 'hello');
    expect(sheet.entries[1].translations['ja'], 'さようなら');

    // toMap / fromMap
    final map = sheet.toMap();
    final restored = LocalizationSheet.fromMap(map);
    expect(restored.locales, ['en', 'ja']);
    expect(restored.entries.length, 2);
    expect(restored.entries[0].key, 'hello');
    expect(restored.entries[1].translations['en'], 'Goodbye');
  });

  /// 空のロケール・エントリでの生成やfromMapの異常系も検証
  /// Arrange-Act-Assertパターン
  test('LocalizationSheet edge cases', () {
    // Arrange: 空ロケール・空エントリ
    final sheet = LocalizationSheet(locales: [], entries: []);
    expect(sheet.locales, isEmpty);
    expect(sheet.entries, isEmpty);

    // fromMap: 不正なMap
    final restored = LocalizationSheet.fromMap({});
    expect(restored.locales, isEmpty);
    expect(restored.entries, isEmpty);
  });
}
