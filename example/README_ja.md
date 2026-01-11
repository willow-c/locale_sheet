# サンプルExcelファイルの説明

[README (English)](./README.md) | [README (日本語)](./README_ja.md)

このファイルは、locale_sheetパッケージの動作確認やテスト用のサンプルデータです。

- `sample.xlsx` ... Excelで開いて編集・保存できるシンプルな例（key, en, ja列）

## サンプル内容

### Sheet1

|key|en|ja|zh|zh_TW|zh-Hant-HK|description|備考|
|:--|:--|:--|:--|:--|:--|:--|:--|
|hello|Hello|こんにちは|你好|你好|你好|the text 'Hello'|こんにちはの文言|
|bye|Goodbye|さようなら|再见|再見|再見|the text 'Goodbye'|さようならの文言|

### Sheet2

|key|ja|fr|
|:--|:--|:--|
|hello|こんにちは|Bonjour|
|bye|さようなら|Au revoir|

## ロケール列の判別ルール

- ヘッダ行の各セルがロケール文字列かどうか判断し、ロケール列のみを出力対象とします。`key` 列およびロケール列に該当しない列（例: `description`, `備考`）は出力されません。
- `-` と `_` は等価に扱います（`zh-Hant-HK` と `zh_Hant_HK` は同一視）。
- 大文字小文字は比較時に区別しません（実装上はトリムを行い、解析時に区切りを統一して検証します）。詳細は `lib/src/core/model_helpers.dart` の `normalizeLocaleTag` / `isValidLocaleTag` を参照してください。

## ARB 出力時の振る舞い

- ARB ファイル名は Flutter の慣例に合わせてアンダースコアを使います。たとえばヘッダが `en`、`zh_TW`、`zh-Hant-HK` の場合、それぞれの出力ファイルは次のようになります：
  - `app_en.arb`
  - `app_zh_TW.arb`
  - `app_zh_Hant_HK.arb`
- `@@locale` フィールドには、ファイル名と一致するようにアンダースコアで正規化されたロケールタグが設定されます。例えば、ヘッダ `zh-Hant-HK` は `@@locale` では `zh_Hant_HK` となります。
- Windows の予約語（`CON`, `PRN`, `AUX`, `NUL`, `COM1`…など）や末尾にスペース/ピリオドがあるタグはファイル名として拒否されます。

## `key` 列について

- 先頭ヘッダ行に `key` 列が存在することが必須です。`key` 列の値が各文言のリソースキーになります。

## CLI 実行例

```bash
dart run locale_sheet export --input example/sample.xlsx --format arb --out ./lib/l10n --sheet-name Sheet1 --default-locale en --description-header description
```

- 入力ファイル: `example/sample.xlsx`
- 出力フォーマット: `arb`
- 出力先: `./lib/l10n`
- 出力対象シート: `Sheet1`
- デフォルトロケール: `en`
- 説明文のヘッダ: `description`
