---
description: Audio/Scheduler 層のコード変更時の注意点
globs:
  - "lib/strudel/audio/**"
  - "lib/strudel/scheduler/**"
  - "spec/audio/**"
  - "spec/scheduler/**"
---

# Audio Pipeline 注意事項

## VCA (PortAudio 出力)

- blocking write モードで動作。PortAudio コールバックは使っていない
- `Pa_WriteStream` を `blocking: true` で FFI 再アタッチし、GVL を解放している
- これにより FileWatcher（listen gem）等の他スレッドが動作可能になる
- CHUNK_SIZE (128 samples, 約2.9ms) 単位で生成し、タイミング精度を確保

## Cyclist (スケジューラー)

- `generate(frame_count)` は mutex 内でパターン照会 + 音声レンダリングを行う
- CPS（cycles per second）を Rational 化して累積ドリフトを防いでいる
- onset を持つ Hap のみがサウンドをトリガーする

## エフェクト管理

- delay, reverb, duck は **orbit 単位**で管理される（Strudel JS と同じ設計）
- 各 orbit は独立した DelayLine, Reverb, DuckEnvelope インスタンスを持つ
- mix_players でボイスを orbit ごとにバッファリングし、エフェクト適用後に合算

## サンプル再生

- SamplePlayer: WAV データを直接再生。speed でピッチ変更
- SynthPlayer: オシレータベース（sine, sawtooth, square, triangle, supersaw, white）
- サンプルレートは 44100 固定前提
