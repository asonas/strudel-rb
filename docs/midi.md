# MIDI Input

strudel-rb では本家 Strudel と同じ方式で MIDI CC 値をパターンに織り込めます。

## Basic Usage

```ruby
ctrl = midi_input("IAC Driver Bus 1")

track { sound("bd*4").gain(ctrl.cc(7)) }
track { sound("hh*8").lpf(ctrl.cc(1).range(200, 4000)) }
```

- `midi_input(device_name)` — MIDI入力デバイスを開きます。同じ名前で何度呼んでも同じインスタンスが返ります
- `input.cc(cc_number, channel = nil)` — 指定CC（任意でチャンネル指定）の最新値を 0.0..1.0 で返す Pattern を返します
- `.range(min, max)` — 0..1 を min..max にリスケールする既存メソッドをそのまま使えます

## Internals

MIDIリーダーは専用スレッドで動き、`Strudel::Midi::Input` の Mutex 保護された Hash にCC値を書き込みます。`input.cc(n)` は `Pattern.ref` を介してクエリ時にこのHashを読むので、パターンを書き直さずにノブで値が変わります。

更新粒度は **Hap（イベント）発火単位** です。音が鳴っていない間はノブを回しても反映されません。連続的なボリュームフェードが必要な場合はサンプル単位のミキサー拡張が別途必要になります（本プランには含まれません）。

## Limitations (v1)

- 再接続サポートなし。デバイス切断時はスレッドが静かに終了します
- CC状態の永続化なし。セッション終了で値はリセットされます（将来 `~/.cache/strudel-rb/midi-<device>.json` に保存する想定）
- チャンネル未指定の `cc(n)` は最後に受信したチャンネルの値を返します
