# Sample Excel file

[README (English)](./README.md) | [README (日本語)](./README_ja.md)

This file contains sample data used for testing and verifying the behavior of the `locale_sheet` package.

- `sample.xlsx` — a simple example (columns: `key`, `en`, `ja`) that can be opened and edited with Excel.

## Contents

| key   | en     | ja         |
|-------|--------|------------|
| hello | Hello  | こんにちは |
| bye   | Goodbye| さようなら |

## Usage

1. Open `sample.xlsx` in Excel and edit/save as needed.
2. Use the `locale_sheet` CLI or API with `--input example/sample.xlsx` (or equivalent) to convert the file.
