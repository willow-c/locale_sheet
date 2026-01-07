import 'package:locale_sheet/src/core/localization_bundle.dart';
import 'package:locale_sheet/src/core/localization_entry.dart';

/// 解析済みのローカライズデータを表すシート表現。
///
/// - `locales`: ヘッダの2列目以降に並ぶロケールコードの順序リスト。
/// - `entries`: 各行（`LocalizationEntry`）のリスト。
class LocalizationSheet {
  /// Create a sheet model from the given locales and entries.
  LocalizationSheet({required this.locales, required this.entries});

  /// MapからLocalizationSheetを復元（デシリアライズ用）
  factory LocalizationSheet.fromMap(Map<String, dynamic> map) {
    final locales = (map['locales'] as List?)?.cast<String>() ?? <String>[];
    final entriesRaw = (map['entries'] as List?) ?? <dynamic>[];
    final entries = entriesRaw
        .map(
          (e) => e is LocalizationEntry
              ? e
              : LocalizationEntry.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return LocalizationSheet(locales: locales, entries: entries);
  }

  /// このシートをMap形式に変換（シリアライズ用）
  Map<String, dynamic> toMap() => {
    'locales': locales,
    'entries': entries.map((e) => e.toMap()).toList(),
  };

  /// ロケールコードの順序リスト（ヘッダの2列目以降）。
  final List<String> locales;

  /// シートの各行を表すエントリのリスト。
  final List<LocalizationEntry> entries;

  /// シートをロケールごとのバンドルにグルーピングします。
  /// 各 `LocalizationBundle` には、そのロケールで値が存在するキーのみが含まれます。
  ///
  /// Returns a list of `LocalizationBundle` in the same order as `locales`.
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
  ///
  /// Example:
  /// ```dart
  /// final bundle = sheet.bundleFor('en');
  /// ```
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
