---
description: Pattern/Core 層の設計規約とドメイン知識
globs:
  - "lib/strudel/core/**"
  - "spec/core/**"
---

# Pattern/Core 設計規約

## 基本設計

Pattern は「State（時間範囲）を受け取り Hap（イベント）の配列を返す関数」。この関数型設計を崩さない。

## Fraction

- Rational ラッパー。全ての時間計算で使用する
- 浮動小数点を時間計算に使わない。長時間セッション（ライブコーディング）での累積ドリフトを防ぐため
- `Fraction.new(Rational(1, 4))` のように Rational で初期化する

## TimeSpan

- begin_time / end_time の時間区間
- `span_cycles` でサイクル境界をまたぐクエリを分割する。Pattern の query 内では必ずこれを使う
- `intersection` で2つの TimeSpan の交差を計算。nil を返す場合がある

## Hap

- **whole**: イベント全体の論理的時間範囲。onset（開始点）の判定に使う
- **part**: 現在のクエリ範囲と交差した可視部分
- **value**: 音名、コントロール値などのペイロード（String, Hash, Integer など）
- `has_onset?` は whole の begin_time が part の begin_time と一致するかで判定

## Inner Join パターン

set_control や apply_op では inner join セマンティクスを使う:
1. 左パターンの Hap を取得
2. 各 Hap の whole（または part）の時間範囲で右パターンを照会
3. 左右の part の intersection を計算し、交差があれば結合

## 新しい Pattern メソッドを追加するとき

- ファクトリメソッド（クラスメソッド）: `Pattern.new { |state| ... }` で新しいパターンを返す
- 変換メソッド（インスタンスメソッド）: 既存パターンの query を包む新しい Pattern を返す
- `state.span.span_cycles` でサイクル分割を行うことを忘れない
