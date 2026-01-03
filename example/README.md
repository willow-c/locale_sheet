# サンプルExcelファイルの説明

このファイルは、locale_sheetパッケージの動作確認やテスト用のサンプルデータです。

- `sample.csv` ... Excelで開いて編集・保存できるシンプルなCSV例（key, en, ja列）
- 実際の運用ではExcel形式（.xlsx）を推奨しますが、CSVでも構造は同じです

## サンプル内容

| key   | en     | ja         |
|-------|--------|------------|
| hello | Hello  | こんにちは |
| bye   | Goodbye| さようなら |

## 使い方例

1. Excelでsample.csvを開き、必要に応じて編集・保存
2. `locale_sheet` CLIやAPIで `--input example/sample.xlsx` などとして利用

> Excel形式（.xlsx）で保存したファイルも同じ構造で利用できます。
