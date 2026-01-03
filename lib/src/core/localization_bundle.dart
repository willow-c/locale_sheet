import 'model_helpers.dart';

/// ロケール単位の翻訳コレクション。
class LocalizationBundle {
  /// ロケールコード（例: `en`, `ja`）。
  final String locale;

  /// このロケールのキー -> 翻訳文字列マップ。
  final Map<String, String> entries;

  LocalizationBundle(this.locale, Map<String, String> entries)
    : entries = Map.unmodifiable(entries);

  /// キーでの検索。
  String? operator [](String key) => entries[key];

  /// 可変のマップコピーを生成します。
  Map<String, String> toMap() => Map.from(entries);

  /// マップから復元します。
  factory LocalizationBundle.fromMap(String locale, Map<String, dynamic> m) {
    final map = <String, String>{};
    m.forEach((k, v) {
      if (v != null) map[k] = v.toString();
    });
    return LocalizationBundle(locale, map);
  }

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
