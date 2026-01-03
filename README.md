# locale_sheet

`locale_sheet` はスプレッドシート（Excel）を単一の真実の情報源として扱い、ローカライズ文字列を複数形式に変換するための Dart CLI パッケージです。

## 開発に必要なツール

- fvm（Dartバージョン管理、推奨）
- lcov（カバレッジHTMLレポート生成用）

### Dart & fvm

#### Homebrew (Mac)
```bash
brew install dart fvm
```

#### fvm（Dartバージョン管理）
詳しくは https://fvm.app/ を参照してください。

### lcov（カバレッジHTMLレポート用）

#### Mac (Homebrew)
```bash
brew install lcov
```

## 主な機能

- Excel をパースして内部モデルに変換する
- 複数の出力エクスポーター（初期実装: ARB）へ変換する
- ライブラリとしての注入可能な API を提供（テストや自動化に便利）


## ディレクトリ構成（2026年1月時点）

- `bin/` — CLIエントリポイント（`bin/locale_sheet.dart`）
- `lib/` — コア実装（UI非依存）
  - `lib/locale_sheet.dart` — 公開API
  - `lib/src/core/` — ドメインモデル・パーサ・ロジック（例: localization_entry.dart, parser.dart, model.dart, localization_sheet.dart など）
  - `lib/src/cli/` — CLIアダプタ・ロガー（cli.dart, logger.dart）
  - `lib/src/exporters/` — 各種エクスポーター（arb_exporter.dart等）
- `test/` — ユニット/統合テスト（lib/src/の構成に合わせて core/ cli/ exporters/ などサブディレクトリ化）
- `scripts/` — カバレッジ・クリーン用スクリプト（Bash/PowerShell両対応）
- `AGENTS.md` — エージェント/自動化運用方針・履歴

## Excel フォーマット仕様

- 1行目はヘッダ行です。
  - 1列目ヘッダは必須で `key` としてください。
  - 2列目以降はロケールコード（例: `en`, `ja`, `es`）を指定します。
- 2行目以降は翻訳行です。
  - 1列目: 翻訳キー（例: `hello`）
  - 2列目以降: 各ロケールの翻訳文字列。空欄は未定義として扱われます。

例:

```
key,en,ja
hello,Hello,こんにちは
bye,Goodbye,さようなら
```

※ 現在は単純な文字列のみサポートしています。プレースホルダや複数形、説明などは今後の拡張候補です。

## CLI（コマンドライン）

依存を取得して実行します（`fvm` を利用することを推奨します）:

```bash
fvm dart pub get
```

エクスポート例:

```bash
fvm dart run bin/locale_sheet.dart export --input path/to/translations.xlsx --format arb --out ./lib/l10n
```

- `--input`/`-i`: 入力 XLSX ファイルのパス
- `--format`: 出力形式（現状は `arb` のみ）
- `--out`/`-o`: 出力ディレクトリ（存在しない場合は作成されます）

CLI のヘルプは日本語化されており、`export --help` で詳細が確認できます。

出力例: `./lib/l10n/app_en.arb`, `./lib/l10n/app_ja.arb`

ExportCommand の注入とテスト方法
---------------------------------

`ExportCommand` はテストやカスタム処理のために内部依存を注入できるようになっています。主に以下をコンストラクタで差し替え可能です。

- `logger`: `Logger` 実装を渡してログ出力をカスタマイズできます（デフォルトは `SimpleLogger`）。
- `parser`: `ExcelParser` を差し替えて独自のパーサやフェイクパーサを使用できます（ユニットテストで便利）。
- `exporters`: `LocalizationExporter` のマップを渡して、サポートする出力フォーマットを追加・差し替えできます。

簡単な注入例（テスト用）:

```dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:locale_sheet/src/cli/cli.dart';
import 'package:locale_sheet/src/cli/logger.dart';

final fakeParser = /* ExcelParser のサブクラスで fake 実装 */;
final fakeExporter = /* LocalizationExporter のフェイク */;

final cmd = ExportCommand(
  logger: SimpleLogger(),
  parser: fakeParser,
  exporters: {'arb': fakeExporter},
);

final runner = CommandRunner<int>('locale_sheet', 'test')..addCommand(cmd);
await runner.run(['export', '--input', 'path/to/file.xlsx']);
```

この注入設計により、ファイル I/O や実際のエクスポート処理をモックして `ExportCommand` の振る舞いのみを検証できます。

### エラーハンドリング

このツールは、一般的なエラー状況を検知し、わかりやすいメッセージを出力します。

- **不正な引数:** `--input` が指定されない場合や、`--format` にサポートされていない形式が渡された場合、コマンドはエラーメッセージと共に終了します。
- **ファイルI/Oエラー:** 入力ファイルが存在しない場合や、出力ディレクトリに書き込めない場合など、ファイルシステムに関する問題が発生するとエラーが報告されます。
- **パースエラー:** Excel ファイルが破損している、または期待されるフォーマット（1行目がヘッダーなど）でない場合、パース処理中にエラーが発生します。

問題が発生した場合は、CLIに出力されるエラーメッセージを確認してください。

## サンプル実行
```bash
fvm dart run bin/locale_sheet.dart export --input example/sample.xlsx --format arb --out ./lib/l10n
```

## プログラム的 API

ライブラリの公開関数を使って、コード内から直接変換できます。

```dart
import 'package:locale_sheet/locale_sheet.dart';

await convertExcelToArb(inputPath: 'path/to/translations.xlsx', outDir: 'lib/l10n');
```

テストしやすさのため、バイト列を受け取る `convertExcelBytesToArb` と、エクスポーターを注入できる設計になっています。

また、より柔軟な使い方として、バイト列を直接扱う `convertExcelBytesToArb` 関数も利用できます。これにより、ファイルシステムからではなく、ネットワークやメモリ上のデータから直接変換処理を行うことができます。

```dart
import 'dart:typed_data';
import 'package:locale_sheet/locale_sheet.dart';

// 例: Uint8List のバイトデータを取得する何らかの処理
// Uint8List excelBytes = await getExcelBytesFromSomewhere();

// ArbExporter のインスタンスを作成
final arbExporter = ArbExporter();

// バイトデータとエクスポーターを指定して変換を実行
// await convertExcelBytesToArb(excelBytes, arbExporter, 'lib/l10n');
```
この方法は、テストコードを書く際や、カスタムのデータソースから変換する場合に特に便利です。

プログラムから CLI コマンドを直接利用する
---------------------------------

`ExportCommand` は公開 API としてエクスポートされているため、`CommandRunner` に登録してプログラム内部から実行できます。これは CLI と同じ挙動をライブラリ経由で呼び出したい場合に便利です。

```dart
import 'package:args/command_runner.dart';
import 'package:locale_sheet/locale_sheet.dart';

void main() async {
  final runner = CommandRunner<int>('locale_sheet', 'programmatic runner')
    ..addCommand(ExportCommand());

  // コマンドラインと同じ引数で実行可能
  await runner.run(['export', '--input', 'path/to/file.xlsx', '--out', './lib/l10n']);
}
```

また、`ExportCommand` のコンストラクタは `logger`, `parser`, `exporters` を注入できるため、ユニットテストやカスタム処理の差し替えが容易です。


## テストとカバレッジ・自動化方針

- すべてのソースファイルに1:1でテストファイルを用意し、カバレッジレポート（lcov.info）で不足箇所を可視化・改善します。
- カバレッジ・クリーン・ビルド等のスクリプトは scripts/ 配下にBash/PowerShell両対応で用意。
- エージェント/自動化によるコード・ドキュメント生成・リファクタ履歴は AGENTS.md に記録。
- クロスプラットフォーム（Windows/macOS/Linux）で動作確認済み。

## クリーンアップ（生成物・テスト結果の削除）

開発中に生成されるカバレッジ・テスト生成物や .arb ファイル、l10n ディレクトリなどを一括削除できます。

### Mac/Linux (Bash)
```bash
bash scripts/clean.sh
```

### Windows (PowerShell)
```powershell
pwsh scripts/clean.ps1
```

主に削除されるもの:
- coverage/ ディレクトリ
- .dart_tool/ ディレクトリ
- l10n/ ディレクトリ（lib/test配下など）
- *.arb ファイル
- .DS_Store など

### テスト実行

```bash
fvm dart test
```

### カバレッジ（lcov）をワンコマンドで生成

#### Mac/Linux (Bash)

```bash
bash scripts/coverage.sh
```

#### Windows (PowerShell)

```powershell
pwsh scripts/coverage.ps1
```

#### Makefile（Mac/Linux/WSL）

```bash
make coverage
```

#### Dartコマンド（手動実行・クロスプラットフォーム）

```bash
fvm dart test --coverage=coverage
fvm dart pub global run coverage:format_coverage --packages=.dart_tool/package_config.json --in=coverage --out=coverage/lcov.info --lcov
```

> どちらも `coverage/lcov.info` を生成します。

> `scripts/coverage.sh`（Bash）と `scripts/coverage.ps1`（PowerShell）は `fvm` があれば自動で利用し、なければ `dart` を使います。
> どちらも `coverage/lcov.info` を生成し、`genhtml` コマンドがあれば `coverage/html/index.html` も自動生成します。

#### HTMLカバレッジレポートの閲覧

`genhtml` コマンドがインストールされていれば、上記スクリプト実行後に `coverage/html/index.html` をブラウザで開くことで、視覚的なカバレッジレポートを確認できます。

CI等では `coverage/lcov.info` を利用してください。


## 変更履歴（最近の主要な変更・運用）

- ディレクトリ構成を core/ cli/ exporters/ サブディレクトリ化し、責務ごとに整理
- すべてのソースファイルに1:1でテストファイルを用意し、カバレッジ100%を目指す運用に
- AGENTS.mdを新設し、エージェント/自動化による履歴・運用方針を明記
- CLIをCommandRunnerベースに移行し、ExportCommandをlib/src/cli/cli.dartに移動（テスト容易性向上）
- convertExcelToArbのファイル読み取りを同期→非同期に変更
- Loggerインターフェース導入、CLIメッセージ日本語化
- ARB出力でキーをアルファベット順にソートし、出力差分を安定化

## 拡張ポイント

- `lib/src/exporters/` に新しいエクスポーター（例: `resx_exporter.dart`, `json_exporter.dart`）を追加できます。
- モデルとパーサを拡張すれば、プレースホルダや複数形、説明の取り込みが可能です。

### 新しいエクスポーターの追加

このツールは `arb` 形式以外にも、JSON や iOS の `.strings` などの形式に対応できるよう拡張可能です。新しい出力形式を追加する手順は以下の通りです。

#### 1. Exporter クラスの作成

まず、 `lib/src/exporters/` ディレクトリに新しい Dart ファイルを作成します。ファイル名は `json_exporter.dart` のように、`_exporter.dart` で終わるようにします。

そのファイルで `LocalizationExporter` インターフェースを実装したクラスを作成します。このインターフェースは `export` メソッドを一つだけ持ちます。

`export` メソッドは、パースされた `LocalizationSheet` データと出力先ディレクトリ `outDir` を受け取ります。このメソッド内で、各ロケールに対応するファイル（例: `en.json`, `ja.json`）を生成するロジックを実装します。

**`lib/src/exporters/json_exporter.dart` の実装例:**

```dart
import 'dart:convert';
import 'dart:io';

import '../core/model.dart';
import 'exporter.dart';

/// JSON 形式でローカライズ情報をエクスポートするクラス
class JsonExporter implements LocalizationExporter {
  @override
  Future<void> export(LocalizationSheet sheet, String outDir) async {
    final dir = Directory(outDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    for (final locale in sheet.locales) {
      final Map<String, String> translations = {};
      for (final entry in sheet.entries) {
        final value = entry.translations[locale];
        if (value != null) {
          translations[entry.key] = value;
        }
      }

      // ファイルに出力
      final fileName = '$locale.json';
      final file = File('${dir.path}/$fileName');
      final encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(translations));
    }
  }
}
```

#### 2. CLI への登録

次に、作成した Exporter を CLI から利用できるように登録します。

`lib/src/cli/cli.dart` ファイルを開き、`ExportCommand` クラス内にある `_exporters` マップに新しいエントリーを追加します。キーには `--format` オプションで指定する名前（例: `json`）、値には作成した Exporter のインスタンスを指定します。

```dart
// lib/src/cli/cli.dart

// ... (他の import)
// import 'package:locale_sheet/src/exporters/json_exporter.dart'; // 作成した Exporter をインポート

class ExportCommand extends Command<int> {
  // ...

  final Map<String, LocalizationExporter> _exporters = {
    'arb': ArbExporter(),
    // 'json': JsonExporter(), // ここに追加
  };

  // ...
}
```
*注: 上記のコードは説明のための例です。実際に`json_exporter.dart`ファイルを作成し、インポート行のコメントを解除して`_exporters`マップに追加する必要があります。*

#### 3. 動作確認

これで、CLI から新しいフォーマットを指定できるようになります。

```bash
# JSON 形式でエクスポート
fvm dart run bin/locale_sheet.dart export --input example/sample.xlsx --format json --out ./lib/l10n
```

## ライセンス

MIT
