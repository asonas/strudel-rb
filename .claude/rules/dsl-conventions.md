---
description: DSL にコントロールや関数を追加するときの規約
globs:
  - "lib/strudel/dsl.rb"
  - "spec/dsl*"
---

# DSL 規約

## コントロールの追加

新しいコントロール（音量、フィルター等）は `set_control` パターンで追加する:

```ruby
def lpf(value)
  set_control(:lpf, value)
end
```

- `set_control` は内部で inner join を行い、パターン値にも対応する
- キー名は Strudel JS の API 名と一致させる

## エイリアス

Strudel JS に合わせたエイリアスを提供する:

```ruby
alias_method :delayt, :delaytime
alias_method :dfb, :delayfeedback
alias_method :sz, :roomsize
```

## register によるカスタムメソッド

`register` は Pattern クラスに動的にメソッドを定義する:

```ruby
register(:rlpf) do |x, pat|
  pat.lpf(Pattern.pure(x).mul(12).pow(4))
end
```

- ブロックの最後の引数が `self`（呼び出し元の Pattern）になる
- DSL モジュール内の `register` 呼び出しは `module_function` で公開済み

## track / _track

- `track { ... }` でトラック登録、`_track { ... }` でミュート状態で登録
- ブロックは Pattern を返す必要がある
- エラーが起きたトラックは他トラックに影響せず単独で無視される
