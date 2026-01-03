import '../core/model.dart';

/// [LocalizationSheet] をファイルに書き出すエクスポーターの共通インターフェース。
abstract class LocalizationExporter {
  Future<void> export(LocalizationSheet sheet, String outDir);
}
