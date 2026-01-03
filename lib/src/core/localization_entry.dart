import 'model_helpers.dart';

/// 単一のローカライズ項目（スプレッドシートの1行に相当）。
class LocalizationEntry {
  /// ローカライズキー（例: `hello`）。
  final String key;

  /// ロケールコード -> 翻訳文字列のマップ。
  /// 値が `null` の場合、そのロケールに対する翻訳が提供されていないことを示します。
  final Map<String, String?> translations;

  /// 任意の説明やコメント。
  final String? description;

  LocalizationEntry(
    this.key,
    Map<String, String?> translations, {
    this.description,
  }) : translations = Map.unmodifiable(Map.from(translations));

  /// 指定した [locale] の翻訳を返します。存在しない場合は `null` を返します。
  String? translationFor(String locale) => translations[locale];

  /// コピーを作成します。部分的な上書きが可能です。
  LocalizationEntry copyWith({
    String? key,
    Map<String, String?>? translations,
    String? description,
  }) {
    return LocalizationEntry(
      key ?? this.key,
      translations ?? Map<String, String?>.from(this.translations),
      description: description ?? this.description,
    );
  }

  /// シリアライズ用マップ。
  Map<String, Object?> toMap() => {
    'key': key,
    'translations': translations,
    'description': description,
  };

  /// マップから復元します。
  factory LocalizationEntry.fromMap(Map<String, dynamic> m) {
    final trans = <String, String?>{};
    if (m['translations'] is Map) {
      (m['translations'] as Map).forEach((k, v) {
        trans[k.toString()] = v?.toString();
      });
    }
    return LocalizationEntry(
      m['key'].toString(),
      trans,
      description: m['description']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is LocalizationEntry &&
        other.key == key &&
        mapEquals(other.translations, translations) &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(key, mapHash(translations), description);
}
