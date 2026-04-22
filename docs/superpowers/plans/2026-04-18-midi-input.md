# MIDI Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MIDIデバイスのCC値をパターンに織り込む仕組み（Strudel本家の `midin` / `cc` 相当）をstrudel-rbに実装し、ライブコーディング中にノブでパラメータを動的制御できるようにする。

**Architecture:** 本家Strudelと同じ「ref Pattern」方式を採用する。MIDIリーダースレッドが共有ストア（Mutex保護のHash）にCC値を書き込み、`Pattern.ref` がクエリ時にストアから最新値を読み出す。`pure(1).with_value { accessor.call }.inner_join` の合成でPatternに仕立てる。デバイス接続は `Strudel::Midi::Registry` でデバイス名をキーにシングルトン化し、ライフサイクルは `Session#stop` から停止する。

**Tech Stack:** Ruby / unimidi gem / Minitest / 既存の `Strudel::Pattern` primitives (`pure`, `with_value`, `inner_join`, `range`)

---

## File Structure

作成:
- `lib/strudel/midi/input.rb` — `Strudel::Midi::Input`。1デバイスに対応するMIDI入力クラス。リーダースレッド、CC値ストア、`cc(num, chan=nil)` Patternファクトリを持つ
- `lib/strudel/midi/registry.rb` — `Strudel::Midi::Registry`。デバイス名キーのシングルトンレジストリ
- `spec/midi/input_spec.rb` — `Input`の単体テスト（デバイスI/Oはモック、`record_cc` で直接値を注入して検証）
- `spec/midi/registry_spec.rb` — レジストリの冪等性テスト
- `spec/core/pattern_ref_spec.rb` — `Pattern.ref` の単体テスト

変更:
- `lib/strudel/core/pattern.rb` — `Pattern.ref` クラスメソッドを追加
- `lib/strudel/dsl.rb` — `midi_input(name)` DSLを追加
- `lib/strudel/live/session.rb` — `stop` 時に `Registry.stop_all` を呼ぶ
- `lib/strudel.rb` — 新規ファイルの require を追加
- `Gemfile` — `unimidi` を追加

---

## Task 1: Add unimidi dependency

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add unimidi to Gemfile**

Edit `Gemfile` (insert after `gem "listen"` line):

```ruby
gem "listen"
gem "unimidi"
gem "logger"
```

- [ ] **Step 2: Install**

```bash
bundle install
```

Expected: Gemfile.lock updated with unimidi and its deps (ffi, rbconfig, etc.).

- [ ] **Step 3: Verify gem loads**

```bash
bundle exec ruby -e 'require "unimidi"; puts UniMIDI::Input.all.map(&:name).inspect'
```

Expected: 接続中のMIDI入力デバイス名の配列（未接続なら `[]`）が出力される。エラーにならなければOK。

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git ai-commit
```

期待コミットメッセージ: `Add unimidi dependency for MIDI input support`

---

## Task 2: Pattern.ref primitive

`Pattern.ref(&accessor)` はクエリのたびに `accessor` を評価し、最新値を含むHapを返す。Strudel JSの `ref = (accessor) => pure(1).withValue(() => reify(accessor())).innerJoin()` のRuby版。

**Files:**
- Modify: `lib/strudel/core/pattern.rb`
- Create: `spec/core/pattern_ref_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/core/pattern_ref_spec.rb`:

```ruby
# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Pattern do
  describe ".ref" do
    it "evaluates the accessor on every query" do
      counter = 0
      pattern = Strudel::Pattern.ref { counter += 1 }

      haps1 = pattern.query_arc(0, 1)
      haps2 = pattern.query_arc(1, 2)

      assert_equal 1, haps1.first.value
      assert_equal 2, haps2.first.value
    end

    it "reifies non-pattern values" do
      value = 42
      pattern = Strudel::Pattern.ref { value }
      haps = pattern.query_arc(0, 1)

      assert_equal 42, haps.first.value
    end

    it "returns one hap per cycle" do
      pattern = Strudel::Pattern.ref { 0.5 }
      haps = pattern.query_arc(0, 2)

      assert_equal 2, haps.length
      assert_equal 0.5, haps[0].value
      assert_equal 0.5, haps[1].value
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec ruby -Ilib -Ispec spec/core/pattern_ref_spec.rb
```

Expected: FAIL — `NoMethodError: undefined method 'ref' for Strudel::Pattern`

- [ ] **Step 3: Implement Pattern.ref**

In `lib/strudel/core/pattern.rb`, add after `self.reify` (around line 42):

```ruby
    # Query-time value injection. The accessor block is evaluated on every
    # query, allowing external state (e.g. MIDI CC values) to be threaded
    # into a Pattern without re-evaluation of the user's pattern code.
    # Mirrors Strudel JS's ref().
    def self.ref(&accessor)
      raise ArgumentError, "block is required" unless accessor

      pure(1).with_value { |_| reify(accessor.call) }.inner_join
    end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec ruby -Ilib -Ispec spec/core/pattern_ref_spec.rb
```

Expected: PASS (3 runs, 3 assertions / 0 failures).

- [ ] **Step 5: Run full test suite to verify no regression**

```bash
bundle exec ruby -Ilib -Ispec -e "Dir.glob('spec/**/*_spec.rb').each { |f| require_relative f }"
```

Expected: all existing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add lib/strudel/core/pattern.rb spec/core/pattern_ref_spec.rb
git ai-commit
```

期待コミットメッセージ: `Add Pattern.ref for query-time value injection`

---

## Task 3: Midi::Input value store (no device I/O yet)

まずI/Oなしの純粋な値ストアとしてクラスを作る。`record_cc(cc, chan, raw_value)` で値を注入でき、`cc(num, chan=nil)` で Pattern を返す。テスト容易性のため device open は次タスクに分離。

**Files:**
- Create: `lib/strudel/midi/input.rb`
- Create: `spec/midi/input_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/midi/input_spec.rb`:

```ruby
# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Midi::Input do
  describe "#cc" do
    it "returns 0.0 when no CC has been received" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      pattern = input.cc(7)

      haps = pattern.query_arc(0, 1)
      assert_equal 0.0, haps.first.value
    end

    it "returns the latest CC value normalized to 0.0..1.0" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      input.record_cc(7, 1, 127)

      haps = input.cc(7).query_arc(0, 1)
      assert_in_delta 1.0, haps.first.value, 0.0001
    end

    it "normalizes midpoint CC to ~0.5" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      input.record_cc(7, 1, 64)

      haps = input.cc(7).query_arc(0, 1)
      assert_in_delta 64.0 / 127.0, haps.first.value, 0.0001
    end

    it "reflects later updates on subsequent queries (Pattern.ref semantics)" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      pattern = input.cc(7)

      input.record_cc(7, 1, 0)
      assert_in_delta 0.0, pattern.query_arc(0, 1).first.value, 0.0001

      input.record_cc(7, 1, 127)
      assert_in_delta 1.0, pattern.query_arc(1, 2).first.value, 0.0001
    end

    it "filters by channel when chan is given" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      input.record_cc(7, 1, 127)
      input.record_cc(7, 2, 0)

      ch1 = input.cc(7, 1).query_arc(0, 1).first.value
      ch2 = input.cc(7, 2).query_arc(0, 1).first.value

      assert_in_delta 1.0, ch1, 0.0001
      assert_in_delta 0.0, ch2, 0.0001
    end

    it "is thread-safe for concurrent writes and reads" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      pattern = input.cc(7)

      writer = Thread.new do
        1000.times { |i| input.record_cc(7, 1, i % 128) }
      end
      reader = Thread.new do
        1000.times { pattern.query_arc(0, 1) }
      end

      [writer, reader].each(&:join)
      # if no exception was raised, the mutex is working
      assert true
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec ruby -Ilib -Ispec spec/midi/input_spec.rb
```

Expected: FAIL — `NameError: uninitialized constant Strudel::Midi::Input`.

- [ ] **Step 3: Implement the value store**

Create `lib/strudel/midi/input.rb`:

```ruby
# frozen_string_literal: true

require "unimidi"

module Strudel
  module Midi
    # Wraps a single MIDI input device. Owns a background reader thread that
    # keeps an internal store of the latest CC value per (cc_number, channel).
    # Exposes `cc(num, chan=nil)` returning a Pattern whose query-time value
    # is the most recently received CC value (normalized to 0.0..1.0).
    #
    # Thread model: the reader thread is the only writer. Pattern queries
    # (audio/scheduler threads) are readers. A Mutex protects all access.
    class Input
      STATUS_CC = 0xB0

      attr_reader :device_name

      def initialize(device_name:, open_device: true)
        @device_name = device_name
        @mutex = Mutex.new
        @values = Hash.new(0.0)             # {cc_num => normalized_value}
        @values_by_channel = {}             # {chan => {cc_num => normalized_value}}
        @reader_thread = nil
        @stopping = false
        open if open_device
      end

      # Inject a CC value (used by reader thread and tests). raw_value is 0..127.
      def record_cc(cc_num, channel, raw_value)
        scaled = raw_value.to_f / 127.0
        @mutex.synchronize do
          @values[cc_num] = scaled
          @values_by_channel[channel] ||= Hash.new(0.0)
          @values_by_channel[channel][cc_num] = scaled
        end
      end

      # Returns a Pattern that, on query, yields the latest CC value.
      # If chan is nil, returns the most recent value regardless of channel.
      def cc(cc_num, chan = nil)
        Pattern.ref { current_value(cc_num, chan) }
      end

      def stop
        @stopping = true
        @reader_thread&.join(1)
        @device&.close
      end

      private

      def current_value(cc_num, chan)
        @mutex.synchronize do
          if chan.nil?
            @values[cc_num]
          else
            (@values_by_channel[chan] ||= Hash.new(0.0))[cc_num]
          end
        end
      end

      def open
        @device = find_device(@device_name)
        unless @device
          warn "[midi] device not found: #{@device_name}"
          return
        end
        @device.open
        start_reader
      end

      def find_device(name)
        UniMIDI::Input.all.find { |d| d.name == name }
      end

      def start_reader
        @reader_thread = Thread.new do
          while !@stopping
            messages = @device.gets
            next if messages.nil? || messages.empty?

            messages.each { |msg| handle_message(msg) }
          end
        rescue StandardError => e
          warn "[midi] reader thread error: #{e.class}: #{e.message}"
        end
      end

      def handle_message(msg)
        data = msg[:data]
        return unless data && data.length >= 3

        status = data[0]
        return unless (status & 0xF0) == STATUS_CC

        channel = (status & 0x0F) + 1  # 1..16
        cc_num  = data[1]
        value   = data[2]
        record_cc(cc_num, channel, value)
      end
    end
  end
end
```

- [ ] **Step 4: Wire up the require**

Edit `lib/strudel.rb` — add after `require_relative "strudel/dsl"` (around line 26):

```ruby
require_relative "strudel/dsl"
require_relative "strudel/midi/input"
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bundle exec ruby -Ilib -Ispec spec/midi/input_spec.rb
```

Expected: PASS (6 runs / 6 assertions, no failures).

- [ ] **Step 6: Run full test suite**

```bash
bundle exec ruby -Ilib -Ispec -e "Dir.glob('spec/**/*_spec.rb').each { |f| require_relative f }"
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/strudel/midi/input.rb lib/strudel.rb spec/midi/input_spec.rb
git ai-commit
```

期待コミットメッセージ: `Add Strudel::Midi::Input with CC value store`

---

## Task 4: Midi::Registry (device singleton)

複数のパターンから `midi_input('IAC Driver Bus 1')` を呼んでも同じInputインスタンスを返す。pattern.rb の再評価時にデバイスを開き直さないために必要。

**Files:**
- Create: `lib/strudel/midi/registry.rb`
- Create: `spec/midi/registry_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/midi/registry_spec.rb`:

```ruby
# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Midi::Registry do
  before do
    Strudel::Midi::Registry.reset!
  end

  describe ".open" do
    it "returns the same instance for the same device name" do
      a = Strudel::Midi::Registry.open("test-device", open_device: false)
      b = Strudel::Midi::Registry.open("test-device", open_device: false)

      assert_same a, b
    end

    it "returns distinct instances for different names" do
      a = Strudel::Midi::Registry.open("dev-1", open_device: false)
      b = Strudel::Midi::Registry.open("dev-2", open_device: false)

      refute_same a, b
    end
  end

  describe ".stop_all" do
    it "stops every registered input and clears the registry" do
      a = Strudel::Midi::Registry.open("dev-1", open_device: false)
      stopped = false
      a.define_singleton_method(:stop) { stopped = true }

      Strudel::Midi::Registry.stop_all

      assert stopped
      assert_empty Strudel::Midi::Registry.inputs
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec ruby -Ilib -Ispec spec/midi/registry_spec.rb
```

Expected: FAIL — `NameError: uninitialized constant Strudel::Midi::Registry`.

- [ ] **Step 3: Implement the Registry**

Create `lib/strudel/midi/registry.rb`:

```ruby
# frozen_string_literal: true

module Strudel
  module Midi
    # Process-wide registry of MIDI Input instances, keyed by device name.
    # Ensures that re-evaluation of pattern.rb does not re-open devices.
    module Registry
      @mutex = Mutex.new
      @inputs = {}

      class << self
        attr_reader :inputs

        def open(device_name, open_device: true)
          @mutex.synchronize do
            @inputs[device_name] ||= Input.new(
              device_name: device_name,
              open_device: open_device
            )
          end
        end

        def stop_all
          @mutex.synchronize do
            @inputs.each_value(&:stop)
            @inputs.clear
          end
        end

        # For tests.
        def reset!
          @mutex.synchronize do
            @inputs.each_value { |i| i.stop rescue nil }
            @inputs.clear
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Wire up the require**

Edit `lib/strudel.rb` — add after the `midi/input` line:

```ruby
require_relative "strudel/midi/input"
require_relative "strudel/midi/registry"
```

- [ ] **Step 5: Run tests**

```bash
bundle exec ruby -Ilib -Ispec spec/midi/registry_spec.rb
bundle exec ruby -Ilib -Ispec -e "Dir.glob('spec/**/*_spec.rb').each { |f| require_relative f }"
```

Expected: registry spec PASSes, full suite still green.

- [ ] **Step 6: Commit**

```bash
git add lib/strudel/midi/registry.rb lib/strudel.rb spec/midi/registry_spec.rb
git ai-commit
```

期待コミットメッセージ: `Add Strudel::Midi::Registry for singleton device access`

---

## Task 5: DSL binding `midi_input(name)`

pattern.rb から `cc = midi_input("IAC Driver Bus 1"); cc.cc(7)` のように使えるようにする。Rubyらしさ: `midi_input` をDSLメソッドとして `module_function` で公開、返り値は `Input` インスタンスそのもの（`cc` メソッドを持つ）。

**Files:**
- Modify: `lib/strudel/dsl.rb`
- Create: `spec/dsl_midi_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/dsl_midi_spec.rb`:

```ruby
# frozen_string_literal: true

require_relative "spec_helper"

describe Strudel::DSL do
  include Strudel::DSL

  before do
    Strudel::Midi::Registry.reset!
  end

  describe "#midi_input" do
    it "returns a Midi::Input keyed by device name" do
      input = midi_input("virtual-device", open_device: false)

      assert_instance_of Strudel::Midi::Input, input
      assert_equal "virtual-device", input.device_name
    end

    it "returns the same input on repeated calls (via Registry)" do
      a = midi_input("virtual-device", open_device: false)
      b = midi_input("virtual-device", open_device: false)

      assert_same a, b
    end

    it "lets patterns consume CC values via #cc" do
      input = midi_input("virtual-device", open_device: false)
      input.record_cc(7, 1, 127)

      pat = input.cc(7).range(0, 100)
      haps = pat.query_arc(0, 1)

      assert_in_delta 100.0, haps.first.value, 0.0001
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec ruby -Ilib -Ispec spec/dsl_midi_spec.rb
```

Expected: FAIL — `NoMethodError: undefined method 'midi_input'`.

- [ ] **Step 3: Implement the DSL method**

Edit `lib/strudel/dsl.rb` — replace the existing line:

```ruby
    module_function :register, :setcps, :setcpm, :setbpm
```

with:

```ruby
    # Opens (or returns cached) a MIDI input device and returns a
    # Strudel::Midi::Input. Use its #cc(num, chan=nil) method to build
    # patterns that read live CC values.
    #
    # Example:
    #   ctrl = midi_input("IAC Driver Bus 1")
    #   track { sound("bd*4").gain(ctrl.cc(7)) }
    def midi_input(device_name, open_device: true)
      Midi::Registry.open(device_name, open_device: open_device)
    end

    module_function :register, :setcps, :setcpm, :setbpm, :midi_input
```

- [ ] **Step 4: Run tests**

```bash
bundle exec ruby -Ilib -Ispec spec/dsl_midi_spec.rb
bundle exec ruby -Ilib -Ispec -e "Dir.glob('spec/**/*_spec.rb').each { |f| require_relative f }"
```

Expected: midi DSL spec PASSes (3 runs, 4 assertions), full suite green.

- [ ] **Step 5: Commit**

```bash
git add lib/strudel/dsl.rb spec/dsl_midi_spec.rb
git ai-commit
```

期待コミットメッセージ: `Add midi_input DSL method`

---

## Task 6: Session lifecycle integration

`Session#stop` で MIDI リーダースレッドも止める。Ctrl+C でライブコーディングを終了したときにデバイスを閉じる。

**Files:**
- Modify: `lib/strudel/live/session.rb`
- Modify: `spec/live/pattern_evaluator_spec.rb` (if a session spec exists) or add simple check

- [ ] **Step 1: Write the failing test**

Create `spec/live/session_midi_spec.rb`:

```ruby
# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Live::Session do
  describe "#stop" do
    it "stops all registered MIDI inputs" do
      Strudel::Midi::Registry.reset!
      input = Strudel::Midi::Registry.open("fake-device", open_device: false)
      stopped = false
      input.define_singleton_method(:stop) { stopped = true }

      session = Strudel::Live::Session.new
      session.stop

      assert stopped
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec ruby -Ilib -Ispec spec/live/session_midi_spec.rb
```

Expected: FAIL — the test registers an input, calls `session.stop`, but the session does not yet clean up MIDI; `stopped` stays false.

- [ ] **Step 3: Update Session#stop**

Edit `lib/strudel/live/session.rb` — replace the existing `stop` method:

```ruby
      def stop
        @watcher&.stop
        @runner&.cleanup
        Strudel::Midi::Registry.stop_all
      end
```

- [ ] **Step 4: Run tests**

```bash
bundle exec ruby -Ilib -Ispec spec/live/session_midi_spec.rb
bundle exec ruby -Ilib -Ispec -e "Dir.glob('spec/**/*_spec.rb').each { |f| require_relative f }"
```

Expected: session midi spec PASSes, full suite green.

- [ ] **Step 5: Commit**

```bash
git add lib/strudel/live/session.rb spec/live/session_midi_spec.rb
git ai-commit
```

期待コミットメッセージ: `Stop MIDI inputs when Session stops`

---

## Task 7: Live integration smoke script

実機MIDI確認用スクリプト。CIには含めないが、手動テストで `bundle exec ruby demo/midi_cc.rb <device_name>` と叩いて動作を目視する。

**Files:**
- Create: `demo/midi_cc.rb`

- [ ] **Step 1: Create the demo script**

Create `demo/midi_cc.rb`:

```ruby
# frozen_string_literal: true

# Smoke test for MIDI input. Run with:
#   bundle exec ruby demo/midi_cc.rb "IAC Driver Bus 1"
# Turn CC #7 on your controller and watch the printed value follow.

require_relative "../lib/strudel"

device_name = ARGV[0] || UniMIDI::Input.all.first&.name
abort "No MIDI input available. Pass device name as arg." unless device_name

puts "Opening #{device_name}..."
input = Strudel::Midi::Registry.open(device_name)

pattern = input.cc(7)
puts "Move CC#7 on your controller. Ctrl+C to exit."

loop do
  value = pattern.query_arc(0, 1).first.value
  printf("\rCC7: %.3f   ", value)
  sleep 0.05
end
```

- [ ] **Step 2: Run manual verification**

```bash
bundle exec ruby demo/midi_cc.rb "IAC Driver Bus 1"
```

Expected: 動かしたノブに追従して0.0..1.0の値が出力される。ユーザーが手元で確認する手順。

- [ ] **Step 3: Commit**

```bash
git add demo/midi_cc.rb
git ai-commit
```

期待コミットメッセージ: `Add demo script for MIDI CC smoke testing`

---

## Task 8: Finalize documentation

README もしくは `docs/midi.md` に簡単な使い方を残す。既存READMEの方針に合わせる。

**Files:**
- Create: `docs/midi.md`

- [ ] **Step 1: Write the doc**

Create `docs/midi.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add docs/midi.md
git ai-commit
```

期待コミットメッセージ: `Document MIDI input usage`

---

## After all tasks

- [ ] **Run full suite one more time**

```bash
bundle exec ruby -Ilib -Ispec -e "Dir.glob('spec/**/*_spec.rb').each { |f| require_relative f }"
```

- [ ] **Hand off to user for live device verification**

ユーザーが実機で `bundle exec ruby demo/midi_cc.rb <device>` を走らせ、ノブの値が追従することを確認する。OK が出たら main に merge。
