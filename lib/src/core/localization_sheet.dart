import 'package:locale_sheet/src/core/localization_bundle.dart';
import 'package:locale_sheet/src/core/localization_entry.dart';

/// 解析済みのローカライズデータを表すシート表現。
///
/// - `locales`: ヘッダの2列目以降に並ぶロケールコードの順序リスト。
/// - `entries`: 各行（`LocalizationEntry`）のリスト。
/// - `ignoredHeaders`: ロケール列として採用しなかったヘッダのリスト。
class LocalizationSheet {
  /// Create a sheet model from the given locales and entries.
  LocalizationSheet({
    required this.locales,
    required this.entries,
    this.ignoredHeaders = const [],
  });

  /// MapからLocalizationSheetを復元（デシリアライズ用）
  factory LocalizationSheet.fromMap(Map<String, dynamic> map) {
    final locales = (map['locales'] as List?)?.cast<String>() ?? <String>[];
    final ignored =
        (map['ignoredHeaders'] as List?)?.cast<String>() ?? <String>[];
    final entriesRaw = (map['entries'] as List?) ?? <dynamic>[];
    final entries = entriesRaw
        .map(
          (e) => e is LocalizationEntry
              ? e
              : LocalizationEntry.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return LocalizationSheet(
      locales: locales,
      entries: entries,
      ignoredHeaders: ignored,
    );
  }

  /// このシートをMap形式に変換（シリアライズ用）
  Map<String, dynamic> toMap() => {
    'locales': locales,
    'entries': entries.map((e) => e.toMap()).toList(),
    'ignoredHeaders': ignoredHeaders,
  };

  /// ロケールコードの順序リスト（ヘッダの2列目以降）。
  final List<String> locales;

  /// シートの各行を表すエントリのリスト。
  final List<LocalizationEntry> entries;

  /// ロケール列として採用しなかったヘッダのリスト（`key` 列と説明列を除く）。
  ///
  /// どの列がロケールとして扱われ、どの列が無視されたかを利用者が確認できる
  /// ようにするためのもの。判定は緩いパターン照合であり、`memo` のような
  /// 一般的な列名もロケールタグとして妥当と判定され得るため、結果を提示
  /// できることが重要になる。
  final List<String> ignoredHeaders;

  /// 2回以上出現するキーを、重複を検出した順で返します。
  ///
  /// スプレッドシート上でキーが重複していても解析自体は成功しますが、
  /// エクスポート時にはロケールごとに後勝ちで上書きされます。
  /// 空セルは上書き対象外となるため、ロケールによって採用される行が
  /// 食い違う可能性があります。呼び出し側はこの結果を使って
  /// 利用者に警告できます。
  ///
  /// Returns the keys that appear more than once, in detection order.
  List<String> get duplicateKeys {
    final seen = <String>{};
    final duplicated = <String>{};
    for (final e in entries) {
      if (!seen.add(e.key)) {
        duplicated.add(e.key);
      }
    }
    return duplicated.toList(growable: false);
  }

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
