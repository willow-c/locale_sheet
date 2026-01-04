# サンプルExcelファイルの説明

[README (English)](./README.md) | [README (日本語)](./README_ja.md)

このファイルは、locale_sheetパッケージの動作確認やテスト用のサンプルデータです。

- `sample.xlsx` ... Excelで開いて編集・保存できるシンプルな例（key, en, ja列）

## サンプル内容

| key   | en     | ja         |
|-------|--------|------------|
| hello | Hello  | こんにちは |
| bye   | Goodbye| さようなら |

## 使い方例

1. Excelでsample.xlsxを開き、必要に応じて編集・保存
2. `locale_sheet` CLIやAPIで `--input example/sample.xlsx` などとして利用
