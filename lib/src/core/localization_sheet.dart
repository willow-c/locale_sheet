import 'localization_bundle.dart';
import 'localization_entry.dart';

/// 解析済みのローカライズデータを表すシート表現。
///
/// - `locales`: ヘッダの2列目以降に並ぶロケールコードの順序リスト。
/// - `entries`: 各行（`LocalizationEntry`）のリスト。
class LocalizationSheet {
  /// このシートをMap形式に変換（シリアライズ用）
  Map<String, dynamic> toMap() => {
    'locales': locales,
    'entries': entries.map((e) => e.toMap()).toList(),
  };

  /// MapからLocalizationSheetを復元（デシリアライズ用）
  factory LocalizationSheet.fromMap(Map<String, dynamic> map) {
    final locales = (map['locales'] as List?)?.cast<String>() ?? <String>[];
    final entriesRaw = (map['entries'] as List?) ?? <dynamic>[];
    final entries = entriesRaw
        .map(
          (e) => e is LocalizationEntry
              ? e
              : LocalizationEntry.fromMap(Map<String, dynamic>.from(e)),
        )
        .toList();
    return LocalizationSheet(locales: locales, entries: entries);
  }
  final List<String> locales;
  final List<LocalizationEntry> entries;

  LocalizationSheet({required this.locales, required this.entries});

  /// シートをロケールごとのバンドルにグルーピングします。
  /// 各 `LocalizationBundle` には、そのロケールで値が存在するキーのみが含まれます。
  List<LocalizationBundle> toBundles() {
    return locales
        .map((locale) {
          final map = <String, String>{};
          for (final e in entries) {
            final v = e.translations[locale];
            if (v != null && v.isNotEmpty) {
              map[e.key] = v;
            }
          }
          return LocalizationBundle(locale, map);
        })
        .toList(growable: false);
  }

  /// 単一の [locale] に対応するバンドルを返します。
  /// 指定したロケールが存在しない場合は [StateError] を投げます。
  LocalizationBundle bundleFor(String locale) {
    if (!locales.contains(locale)) {
      throw StateError('Locale not found: $locale');
    }
    final map = <String, String>{};
    for (final e in entries) {
      final v = e.translations[locale];
      if (v != null && v.isNotEmpty) map[e.key] = v;
    }
    return LocalizationBundle(locale, map);
  }
}
