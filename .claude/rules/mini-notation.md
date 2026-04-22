---
description: Mini-Notation パーサーの変更時の注意点
globs:
  - "lib/strudel/mini/**"
  - "spec/mini/**"
---

# Mini-Notation パーサー

## 構造

Parslet ベースの PEG パーサー。2段階で処理する:

1. **Grammar** — 構文定義。入力文字列を Parslet の parse tree に変換
2. **Transform** — AST 変換。parse tree を Ruby のデータ構造（Hash/Array/String）に変換

変換後の AST を `ast_to_pattern` で Pattern に変換する。

## サポートする記法

| 記法 | 意味 | 例 |
|------|------|-----|
| スペース区切り | シーケンス（fastcat） | `"bd hh sd hh"` |
| `*n` | fast（n倍速） | `"hh*4"` |
| `!n` | replicate（n回繰り返し） | `"bd!3"` |
| `<...>` | slowcat（1サイクルに1つ） | `"<c3 e3 g3>"` |
| `[...]` | グループ | `"[bd hh] sd"` |
| `~` or `-` | 休符 | `"bd ~ sd ~"` |
| `_` | 延長（前のイベントを引き伸ばす） | `"bd _ sd _"` |
| `:n` | サンプル番号 | `"bd:2"` |
| `,` | スタック（並行再生） | `"bd, hh"` |

## Strudel JS との互換性

- Strudel JS の Mini-Notation 仕様と互換性を保つ
- 未実装の記法や挙動の差異がある場合は `workbench/` に記録する
- 参照実装: `/Users/asonas/ghq/codeberg.org/uzu/strudel/packages/mini/`
