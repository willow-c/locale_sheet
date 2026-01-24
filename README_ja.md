# locale_sheet

[![pub package](https://img.shields.io/pub/v/locale_sheet.svg)](https://pub.dev/packages/locale_sheet)
[![license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)
[![CI](https://github.com/willow-c/locale_sheet/actions/workflows/verify.yml/badge.svg)](https://github.com/willow-c/locale_sheet/actions/workflows/verify.yml)

[README (English)](./README.md) | [README (日本語)](./README_ja.md)

locale_sheet は、Excel スプレッドシートを単一の真実の情報源（Single Source of Truth）として扱い、ローカライズ文字列を複数形式（現状: ARB）に変換する軽量な Dart CLI / ライブラリです。

## Quick Start

1. 依存を追加（`pubspec.yaml`）:

    ```yaml
    dev_dependencies:
    locale_sheet: ^0.4.0
    ```

1. パッケージを取得して実行（CLI）:

    ```bash
    dart pub get
    dart run locale_sheet export --input ./example/sample.xlsx --format arb --out ./lib/l10n --sheet-name Sheet1 --default-locale en --description-header description
    ```

    補足:

    - `--default-locale` オプション（短縮 `-d`）は、デフォルト言語とするロケールを指定します。
    - `--default-locale` を省略した場合、シートに `en` が存在すれば `en` をデフォルトとして使用し、なければ最初のロケール列をデフォルトにします。

    例: プレースホルダの自動検出を有効にし、未定義プレースホルダを自動追加する場合:

    ```bash
    dart run locale_sheet export \
      --input ./example/sample.xlsx \
      --format arb \
      --out ./lib/l10n \
      --sheet-name Sheet1 \
      --default-locale en \
      --description-header description \
      --auto-detect-placeholders \
      --treat-undefined-placeholders=add \
      --placeholder-default-type=String
    ```

1. プログラム的に使う（最短）:

    ```dart
    import 'package:args/command_runner.dart';
    import 'package:locale_sheet/locale_sheet.dart';

    void main() async {
      final runner = CommandRunner<int>('locale_sheet', 'programmatic runner')
        ..addCommand(ExportCommand());

      // Programmatic 実行（default-locale 指定例）:
        await runner.run([
          'export',
          '--input',
          'path/to/file.xlsx',
          '--out',
          './lib/l10n',
          '--default-locale',
          'en',
          '--description-header',
          'description',
        ]);

      // またはライブラリ関数を直接呼び出して、`descriptionHeader` を渡すこともできます:
      // await convertExcelToArb(
      //   inputPath: 'path/to/file.xlsx',
      //   outDir: './lib/l10n',
      //   descriptionHeader: 'description',
      // );
    }
    ```

## Features

- Excel (.xlsx) をパースして内部モデルに変換
- ARB 形式への出力（キーはアルファベット順にソート）
- CLI とライブラリの両方で利用可能

## Usage

- CLI オプション:
  - `--input` / `-i`: 入力 XLSX ファイルのパス（必須）
  - `--format`: 出力形式（`arb`）
  - `--out` / `-o`: 出力ディレクトリ（デフォルト: `.`）
  - `--default-locale` / `-d`: デフォルト言語とするロケールを指定します。指定したロケールがシートに存在しない場合は終了コード `64` でエラー終了します。未指定時はシートに `en` があれば `en` を使い、なければ最初のロケール列を使用します。
  - `--sheet-name`: 変換するシート名を指定します。省略した場合はファイル内の最初のシートを使用します。シート名は大文字小文字を区別します（`Sheet1` と `sheet1` は別扱い）し、単一のシート名のみ指定できます。指定したシートが存在しない場合はパース時にエラーとなり処理は失敗します。全てのエクスポーターで有効です。
  - `--description-header`: シートの1行目（ヘッダ）から説明文列を判定するためのヘッダ文字列を指定します。指定された場合、CLI は1行目を検索して一致する列を各キーの `description` として読み取ります。振る舞いの要約:
    - ヘッダが見つかると、その列の各行の値が対応するキーの説明となります。
    - 説明用に指定した列はロケール列の判定対象から除外されます。
    - 指定したヘッダが見つからなかった場合はエラーで終了します。
    - 説明は有効なデフォルトロケールの ARB のみ `@<key>` メタデータとして出力されます。デフォルトロケールの ARB には各エントリに対して `@<key>` オブジェクトが出力されます（説明が無ければ空オブジェクト `{}` になります）。
      ライブラリのヘルパー等で `defaultLocale` のデフォルト値（例: `defaultLocale = 'en'`）に頼る場合、シートに `en` 列が存在すれば `en` に対してメタデータが出力されますが、`en` が存在しない場合は実際に選択された有効なデフォルト（たとえば最初のロケール列）がメタデータ出力の対象になります。非デフォルトロケールの ARB には `@<key>` は含まれません。
  - `--auto-detect-placeholders`: メッセージ本文中の `{name}` のような名前付きプレースホルダを検出して、自動的にプレースホルダとして扱うフラグです（オプトイン）。
  - `--treat-undefined-placeholders`: `warn|ignore|add|error` のいずれかを指定します。検出されたプレースホルダがシート内で宣言されていない場合の振る舞いを制御します。効果を持たせるには `--auto-detect-placeholders` が必要です。振る舞い:
    - `warn`（デフォルト）: 未定義プレースホルダを警告としてログ出力します。
    - `ignore`: 何もしません。
    - `add`: 未定義のプレースホルダをメモリ上で自動追加し、出力される ARB にそのメタデータを含めます（`--placeholder-default-type` で `type` を指定できます）。
    - `error`: 未定義プレースホルダを検出した時点で終了コード `1` で中断します。
  - `--placeholder-default-type`: 自動追加するプレースホルダに割り当てるデフォルトの型（デフォルト: `String`）。
  - ARB 出力に関する注意: エントリにプレースホルダメタデータがある場合、デフォルトロケールの ARB に `@<key>.placeholders` としてプレースホルダ名 → オブジェクトのマッピングが出力されます。各プレースホルダオブジェクトは少なくとも `type` を持ち、`example` や `source`（`detected` / `declared` 等）を含むことがあります。

- 主な公開 API:
  - `convertExcelToArb({required String inputPath, required String outDir, ExcelParser? parser, LocalizationExporter? exporter, String defaultLocale = 'en', String? sheetName, String? descriptionHeader})`
  - `convertExcelBytesToArb(Uint8List bytes, LocalizationExporter exporter, String outDir, {ExcelParser? parser, String defaultLocale = 'en', String? sheetName, String? descriptionHeader})`
  - `ExportCommand` — `CommandRunner` に登録して CLI をプログラム内から実行できます。

両方のヘルパー関数はオプションの `sheetName` 引数を受け取ります。`sheetName` を指定するとその名前のシートが解析され、`null`（省略）ならワークブックの最初のシートが使用されます。指定したシートが存在しない場合は `SheetNotFoundException` が発生します（CLI 実行時は利用可能なシートを表示して終了コード `64` で終了します）。

## Examples

サンプルは `example/` ディレクトリを参照してください（XLSX の最小フォーマット例と出力先のサンプルを含みます）。

## Exit Codes & Error Handling

- `64` — 引数エラー / UsageException
- `1` — 実行時エラー（ファイル I/O やパースエラーなど）

## トラブルシューティング（簡易）

- `Failed to parse arguments.` が表示された場合は、必須オプション（例: `--input`）が正しく指定されているか確認してください。
- `Unsupported format: <format>` が表示された場合は、`--format` にサポートされた値（デフォルト: `arb`）を指定してください。
- `Specified sheet "<name>" not found.` が表示された場合は、シート名が大文字小文字を含めて正しいか、XLSX 内のシート一覧を確認してください。
- `An error occurred: <details>` が表示された場合は、有効な入力ファイルで再実行し、ファイル権限やパスを確認してください。

## License

MIT
