# locale_sheet

[![pub package](https://img.shields.io/pub/v/locale_sheet.svg)](https://pub.dev/packages/locale_sheet)
[![license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)
[![CI](https://github.com/willow-c/locale_sheet/actions/workflows/verify.yml/badge.svg)](https://github.com/willow-c/locale_sheet/actions/workflows/verify.yml)
[![codecov](https://codecov.io/gh/willow-c/locale_sheet/branch/main/graph/badge.svg)](https://codecov.io/gh/willow-c/locale_sheet)

[README (English)](./README.md) | [README (日本語)](./README_ja.md)

locale_sheet は、Excel スプレッドシートを単一の真実の情報源（Single Source of Truth）として扱い、ローカライズ文字列を複数形式（現状: ARB）に変換する軽量な Dart CLI / ライブラリです。

## Quick Start

1. 依存を追加（`pubspec.yaml`）:

    ```yaml
    dev_dependencies:
      locale_sheet: ^0.4.1
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
  - `--locales`: 出力するロケール列を明示指定します（例: `--locales en,ja`）。指定した場合、その列だけがロケールとして扱われ、他の列はすべて無視されます。一致判定は前後の空白と大文字小文字を無視し、`-` と `_` を同一視するため、`--locales zh_tw` は `zh-TW` ヘッダに一致します。指定したタグが1行目に存在しない場合はエラーで終了するため、綴り間違いで言語が黙って抜け落ちることがありません。省略した場合は自動判定になります（下記の注意を参照）。
    - **自動判定は緩い**点に注意してください。英字2〜8文字のヘッダはすべて言語サブタグとして妥当と判定されるため、`memo` `note` `comment` `context` `status` `id` といった一般的な列名もロケールとして扱われ、`app_memo.arb` のようなファイルが生成されます。9文字以上（`description`）や非英字を含む（`備考`）ヘッダは該当しません。ロケール以外の列があるシートでは `--locales` の使用を推奨します。
    - いずれの場合も、ロケールとして採用した列と無視した列の両方がログに出力されるので、結果を確認できます。
    - 区切り文字だけが違う列（`zh-TW` と `zh_TW`）や大文字小文字だけが違う列（`en` と `EN`）は同一のロケールを指し、同じ ARB ファイルに書き出されてしまうため、一方が黙って上書きされる代わりにエラーになります。
  - `--sheet-name`: 変換するシート名を指定します。省略した場合はファイル内の最初のシートを使用します。シート名は大文字小文字を区別します（`Sheet1` と `sheet1` は別扱い）し、単一のシート名のみ指定できます。指定したシートが存在しない場合はパース時にエラーとなり処理は失敗します。全てのエクスポーターで有効です。
  - `--description-header`: シートの1行目（ヘッダ）から説明文列を判定するためのヘッダ文字列を指定します。指定された場合、CLI は1行目を検索して一致する列を各キーの `description` として読み取ります。振る舞いの要約:
    - 一致判定では前後の空白を無視し、大文字小文字も区別しません（`Description` や ` description ` は `description` ヘッダに一致します）。
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
  - `--color` / `--no-color`: ログ出力の ANSI カラーを有効・無効にします（デフォルト: 有効）。ファイルへのリダイレクトや非 TTY 環境では `--no-color` を指定してください。
  - ARB 出力に関する注意: エントリにプレースホルダメタデータがある場合、デフォルトロケールの ARB に `@<key>.placeholders` としてプレースホルダ名 → オブジェクトのマッピングが出力されます。各プレースホルダオブジェクトは少なくとも `type` を持ち、`example` や `source`（`detected` / `declared` 等）を含むことがあります。
  - 重複キーに関する注意: 同じキーが複数の行に現れる場合、CLI はそのキーについて `WARNING` をログ出力して処理を継続します（エラーにはしません）。エクスポート時は**ロケールごとに**後の行が先の行を上書きし、空セルは上書きしないため、行によって空セルの位置が違うと `en` は片方の行・`ja` はもう片方の行から採用される場合があります。この警告が出たらシート側の重複を解消してください。

- 主な公開 API:
  - `convertExcelToArb({required String inputPath, required String outDir, ExcelParser? parser, LocalizationExporter? exporter, String defaultLocale = 'en', String? sheetName, String? descriptionHeader, List<String>? locales})`
  - `convertExcelBytesToArb(Uint8List bytes, LocalizationExporter exporter, String outDir, {ExcelParser? parser, String defaultLocale = 'en', String? sheetName, String? descriptionHeader, List<String>? locales})`
  - `ExportCommand` — `CommandRunner` に登録して CLI をプログラム内から実行できます。
  - `LocalizationSheet.duplicateKeys` — 複数行に現れるキーの一覧を返します。ライブラリ利用時に独自の扱いを実装できます。
  - `ExcelParser.parseWorkbook` — シートの解析に加えて、実際に読んだシート名とワークブックに含まれるシート名の一覧を返します。ファイルのデコードは1回だけです。`parse` と `getSheetNames` を個別に呼ぶ代わりに使ってください。
  - `PlaceholderResolver` — エントリに宣言されていない `{name}` 形式のプレースホルダを検出し、要求された場合は付与します。新しい `LocalizationSheet` と検出結果の一覧を返し、入力のシートは変更しません。検出結果をどう扱うか（警告・無視・中断）は呼び出し側の判断です。

両方のヘルパー関数はオプションの `sheetName` 引数を受け取ります。`sheetName` を指定するとその名前のシートが解析され、`null`（省略）ならワークブックの最初のシートが使用されます。指定したシートが存在しない場合は `SheetNotFoundException` が発生します（CLI 実行時は利用可能なシートを表示して終了コード `64` で終了します）。

## Examples

サンプルは `example/` ディレクトリを参照してください（XLSX の最小フォーマット例と出力先のサンプルを含みます）。

## Exit Codes & Error Handling

終了コードは BSD の `sysexits.h` の慣例に従います。`1` は使用しません。

| コード | 名称 | 発生条件 |
| --- | --- | --- |
| `0` | — | 成功。`--help` などヘルプを明示的に要求した場合も含む |
| `64` | `EX_USAGE` | コマンドラインの誤り: 未知のオプション、必須オプションの欠落、コマンド未指定、未サポートの形式、`--description-header key` |
| `65` | `EX_DATAERR` | 指定と入力が噛み合わない: 指定したシート・ロケール・説明ヘッダが入力に無い、`--default-locale` がシートのロケールに無い、ロケール列が1つも無い、1列目が `key` でない、2つのロケール列が同じファイル名になる、ロケールタグがファイル名として使えない |
| `66` | `EX_NOINPUT` | 入力ファイルを読めない |
| `70` | `EX_SOFTWARE` | 想定外の内部エラー。スタックトレースも出力されます |
| `73` | `EX_CANTCREAT` | 出力を書き込めない |

`64` と `65` の境界は「入力ファイルを開かずに誤りと分かるかどうか」です。

通常のログは標準出力に、警告とエラーは標準エラー出力に書き出されます。警告（重複キー、未宣言のプレースホルダ、効果を持たないオプション）は終了コードを変えません。

ロケール列が1つも無い場合、何も出力しないまま成功と報告するのではなくエラーになります。メッセージには無視した列の一覧が含まれるため、ヘッダの打ち間違いに気付けます。あわせて `--locales` による指定方法も案内されます。

## トラブルシューティング（簡易）

- `Failed to parse arguments.` が表示された場合は、必須オプション（例: `--input`）が正しく指定されているか確認してください。
- `Unsupported format: <format>` が表示された場合は、`--format` にサポートされた値（デフォルト: `arb`）を指定してください。
- `Specified sheet "<name>" not found.` が表示された場合は、シート名が大文字小文字を含めて正しいか、XLSX 内のシート一覧を確認してください。
- `An error occurred: <details>` が表示された場合は、有効な入力ファイルで再実行し、ファイル権限やパスを確認してください。

## License

MIT
