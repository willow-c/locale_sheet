import 'package:locale_sheet/src/core/model_helpers.dart';
import 'package:meta/meta.dart';

/// ロケール単位の翻訳コレクション。
@immutable
class LocalizationBundle {
  /// Create a `LocalizationBundle` with a locale code and its entries.
  LocalizationBundle(this.locale, Map<String, String> entries)
    : entries = Map.unmodifiable(entries);

  /// マップから復元します。
  /// Create a `LocalizationBundle` from a serialized map.
  factory LocalizationBundle.fromMap(String locale, Map<String, dynamic> m) {
    final map = <String, String>{};
    m.forEach((k, v) {
      if (v != null) map[k] = v.toString();
    });
    return LocalizationBundle(locale, map);
  }

  /// ロケールコード（例: `en`, `ja`）。
  final String locale;

  /// このロケールのキー -> 翻訳文字列マップ。
  final Map<String, String> entries;

  /// キーでの検索。
  String? operator [](String key) => entries[key];

  /// 可変のマップコピーを生成します。
  Map<String, String> toMap() => Map.from(entries);

  /// Return a copy of this bundle with optional overrides.
  LocalizationBundle copyWith({String? locale, Map<String, String>? entries}) {
    return LocalizationBundle(
      locale ?? this.locale,
      entries ?? Map.from(this.entries),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is LocalizationBundle &&
        other.locale == locale &&
        mapEquals(other.entries, entries);
  }

  @override
  int get hashCode => Object.hash(locale, mapHash(entries));
}
