import 'package:locale_sheet/src/core/localization_entry.dart';
import 'package:locale_sheet/src/core/localization_sheet.dart';
import 'package:locale_sheet/src/core/placeholder.dart';
import 'package:locale_sheet/src/core/placeholder_detector.dart';
import 'package:meta/meta.dart';

/// メッセージ本文から検出された、宣言されていないプレースホルダ1件。
@immutable
class PlaceholderFinding {
  /// Create a finding for [name] found in [key] under [locale].
  const PlaceholderFinding({
    required this.key,
    required this.locale,
    required this.name,
  });

  /// 検出されたエントリのキー。
  final String key;

  /// 検出されたロケール。
  final String locale;

  /// プレースホルダ名（波括弧を含まない）。
  final String name;

  @override
  bool operator ==(Object other) =>
      other is PlaceholderFinding &&
      other.key == key &&
      other.locale == locale &&
      other.name == name;

  @override
  int get hashCode => Object.hash(key, locale, name);

  @override
  String toString() =>
      'PlaceholderFinding(key: $key, locale: $locale, name: $name)';
}

/// [PlaceholderResolver.resolve] の結果。
@immutable
class PlaceholderResolution {
  /// Create a resolution result.
  const PlaceholderResolution({required this.sheet, required this.undeclared});

  /// 解決後のシート。
  ///
  /// 自動追加を行わなかった場合は入力と同じ内容になります。入力のシートを
  /// 書き換えることはありません。
  final LocalizationSheet sheet;

  /// 宣言されていなかったプレースホルダ。
  ///
  /// 並び順はエントリ順、ロケール順、検出順です。呼び出し側はこの順序に
  /// 依存して「最初の1件」を報告できます。
  final List<PlaceholderFinding> undeclared;
}

/// メッセージ本文からプレースホルダを検出し、宣言との差分を解決します。
///
/// 検出結果をどう扱うか（警告する・無視する・エラーにする）は呼び出し側の
/// 判断であり、本クラスは事実の抽出と、要求された場合の付与だけを行います。
/// ログ出力や終了コードといった表示・制御の関心事は持ちません。
class PlaceholderResolver {
  /// Create a resolver.
  const PlaceholderResolver();

  /// [sheet] の各エントリを走査し、宣言されていないプレースホルダを集めます。
  ///
  /// [addUndeclared] が `true` の場合、見つかったプレースホルダを
  /// [defaultType] の型で付与した新しいシートを返します。`false` の場合は
  /// 内容が同じシートを返します。いずれの場合も入力の [sheet] は変更しません。
  PlaceholderResolution resolve(
    LocalizationSheet sheet, {
    bool addUndeclared = false,
    String defaultType = 'String',
  }) {
    final undeclared = <PlaceholderFinding>[];
    final entries = <LocalizationEntry>[];

    for (final entry in sheet.entries) {
      // 1つのエントリに複数のプレースホルダがある場合、後の検出が先の検出を
      // 上書きしないよう、同じエントリ上で積み上げていく。
      var current = entry;
      for (final locale in sheet.locales) {
        final text = current.translationFor(locale);
        if (text == null) continue;
        for (final name in detectPlaceholders(text)) {
          if (current.placeholders.containsKey(name)) continue;
          undeclared.add(
            PlaceholderFinding(key: current.key, locale: locale, name: name),
          );
          if (addUndeclared) {
            current = current.copyWith(
              placeholders: {
                ...current.placeholders,
                name: Placeholder(type: defaultType, source: 'detected'),
              },
            );
          }
        }
      }
      entries.add(current);
    }

    return PlaceholderResolution(
      sheet: LocalizationSheet(
        locales: sheet.locales,
        entries: entries,
        ignoredHeaders: sheet.ignoredHeaders,
      ),
      undeclared: List.unmodifiable(undeclared),
    );
  }
}
