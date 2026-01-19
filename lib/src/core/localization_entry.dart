import 'package:locale_sheet/src/core/model_helpers.dart';
import 'package:locale_sheet/src/core/placeholder.dart';
import 'package:meta/meta.dart';

/// 単一のローカライズ項目（スプレッドシートの1行に相当）。
@immutable
class LocalizationEntry {
  /// Create a localization entry with a `key` and per-locale `translations`.
  /// Optional `description` can be provided.
  LocalizationEntry(
    this.key,
    Map<String, String?> translations, {
    this.description,
    Map<String, Placeholder>? placeholders,
  }) : translations = Map.unmodifiable(Map.from(translations)),
       placeholders = Map.unmodifiable(Map.from(placeholders ?? {}));

  /// マップから復元します。
  factory LocalizationEntry.fromMap(Map<String, dynamic> m) {
    final trans = <String, String?>{};
    if (m['translations'] is Map) {
      (m['translations'] as Map).forEach((k, v) {
        trans[k.toString()] = v?.toString();
      });
    }
    final ph = <String, Placeholder>{};
    if (m['placeholders'] is Map) {
      (m['placeholders'] as Map).forEach((k, v) {
        if (v is Map) {
          ph[k.toString()] = Placeholder.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }
    return LocalizationEntry(
      m['key'].toString(),
      trans,
      description: m['description']?.toString(),
      placeholders: ph,
    );
  }

  /// ローカライズキー（例: `hello`）。
  final String key;

  /// ロケールコード -> 翻訳文字列のマップ。
  /// 値が `null` の場合、そのロケールに対する翻訳が提供されていないことを示します。
  final Map<String, String?> translations;

  /// 任意の説明やコメント。
  final String? description;

  /// プレースホルダのメタデータ（名前 -> Placeholder）。
  final Map<String, Placeholder> placeholders;

  /// 指定した [locale] の翻訳を返します。存在しない場合は `null` を返します。
  String? translationFor(String locale) => translations[locale];

  /// コピーを作成します。部分的な上書きが可能です。
  LocalizationEntry copyWith({
    String? key,
    Map<String, String?>? translations,
    String? description,
    Map<String, Placeholder>? placeholders,
  }) {
    return LocalizationEntry(
      key ?? this.key,
      translations ?? Map<String, String?>.from(this.translations),
      description: description ?? this.description,
      placeholders:
          placeholders ?? Map<String, Placeholder>.from(this.placeholders),
    );
  }

  /// シリアライズ用マップ。
  Map<String, Object?> toMap() => {
    'key': key,
    'translations': translations,
    'description': description,
    'placeholders': Map.fromEntries(
      placeholders.entries.map((e) => MapEntry(e.key, e.value.toMap())),
    ),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is LocalizationEntry &&
        other.key == key &&
        mapEquals(other.translations, translations) &&
        other.description == description &&
        mapEquals(
          other.placeholders.map((k, v) => MapEntry(k, v.toMap())),
          placeholders.map((k, v) => MapEntry(k, v.toMap())),
        );
  }

  @override
  int get hashCode => Object.hash(
    key,
    mapHash(translations),
    description,
    mapHash(placeholders.map((k, v) => MapEntry(k, v.toMap()))),
  );
}
