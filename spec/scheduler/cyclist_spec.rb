# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Scheduler::Cyclist do
  it "returns stereo buffers (L/R) from #generate" do
    dsl = Object.new.extend(Strudel::DSL)

    cyclist = Strudel::Scheduler::Cyclist.new(sample_rate: 1000, cps: 1.0)
    pat = dsl.n("0*4").scale("c:major").s("sine").pan(0)
    cyclist.set_pattern(pat)

    left, right = cyclist.generate(100)

    assert_equal 100, left.length
    assert_equal 100, right.length
  end

  it "advances cycle position without cumulative drift using Rational arithmetic" do
    # cps=0.55 だと frames_per_cycle=80181.818... → .to_i=80181 で誤差が生じる
    cyclist = Strudel::Scheduler::Cyclist.new(sample_rate: 44100, cps: 0.55)
    dsl = Object.new.extend(Strudel::DSL)
    pat = dsl.sound("bd")
    cyclist.set_pattern(pat)

    # 1000回 generate(128) を呼んだ後のサイクル位置を検証
    1000.times { cyclist.generate(128) }

    # 期待値: 128000 frames / 44100 Hz * 0.55 cps = 128000 * 0.55 / 44100
    expected = Rational(128_000) * Rational(55, 100) / Rational(44_100)
    actual = cyclist.current_cycle.value

    assert_equal expected, actual
  end

  it "uses pitch-shifted sample when note() is used with a sample sound" do
    dsl = Object.new.extend(Strudel::DSL)

    fixtures_path = File.expand_path("../fixtures/samples", __dir__)

    # Play WITHOUT note (plain sample, no pitch shift)
    cyclist_plain = Strudel::Scheduler::Cyclist.new(
      sample_rate: 44100,
      cps: 1.0,
      samples_path: fixtures_path
    )
    pat_plain = dsl.s("pitched_test")
    cyclist_plain.set_pattern(pat_plain)
    left_plain, _ = cyclist_plain.generate(4410)

    # Play WITH note E4 (MIDI 64); pitched_test/0.wav is rooted at C4 (60)
    # so speed should be 2^((64-60)/12) ≈ 1.26, producing different output
    cyclist_pitched = Strudel::Scheduler::Cyclist.new(
      sample_rate: 44100,
      cps: 1.0,
      samples_path: fixtures_path
    )
    pat_pitched = dsl.note("e4").s("pitched_test")
    cyclist_pitched.set_pattern(pat_pitched)
    left_pitched, _ = cyclist_pitched.generate(4410)

    # Both should produce audio
    assert left_plain.any? { |s| s.abs > 0.0001 }, "Plain sample should produce audio"
    assert left_pitched.any? { |s| s.abs > 0.0001 }, "Pitched sample should produce audio"

    # The outputs must differ because pitch shifting changes playback speed
    refute_equal left_plain, left_pitched,
      "note() with sample should produce pitch-shifted (different) output"
  end

  it "passes nil duration to sample player when clip/loop/release are not set" do
    fixtures_path = File.expand_path("../fixtures/samples", __dir__)
    dsl = Object.new.extend(Strudel::DSL)

    # Single event pattern so we can track exactly one player
    cyclist = Strudel::Scheduler::Cyclist.new(
      sample_rate: 44100,
      cps: 2.0, # fast cps -> event_duration = 1/(1*2.0) = 0.5s (1 event per cycle)
      samples_path: fixtures_path
    )
    pat = dsl.s("unpitched_test")
    cyclist.set_pattern(pat)

    # Trigger the event
    cyclist.generate(256)

    # Get the active player and check its hold_duration
    active = cyclist.instance_variable_get(:@active_players)
    assert active.length > 0, "Should have at least one active player"

    player = active.first.player
    hold_duration = player.instance_variable_get(:@hold_duration)
    assert_nil hold_duration,
      "hold_duration should be nil when clip/loop/release are not set (sample plays full length)"
  end

  it "passes event duration to sample player when clip is set" do
    fixtures_path = File.expand_path("../fixtures/samples", __dir__)
    dsl = Object.new.extend(Strudel::DSL)

    cyclist = Strudel::Scheduler::Cyclist.new(
      sample_rate: 44100,
      cps: 2.0,
      samples_path: fixtures_path
    )
    # clip(1) means duration = 1 * event_duration
    pat = dsl.s("unpitched_test").clip(1)
    cyclist.set_pattern(pat)

    # Trigger the event
    cyclist.generate(256)

    # Get the active player and check its hold_duration
    active = cyclist.instance_variable_get(:@active_players)
    assert active.length > 0, "Should have at least one active player"

    player = active.first.player
    hold_duration = player.instance_variable_get(:@hold_duration)
    refute_nil hold_duration,
      "hold_duration should be set when clip is specified"
    assert hold_duration > 0,
      "hold_duration should be positive"
  end

  it "passes event duration to sample player when release is explicitly set" do
    fixtures_path = File.expand_path("../fixtures/samples", __dir__)
    dsl = Object.new.extend(Strudel::DSL)

    cyclist = Strudel::Scheduler::Cyclist.new(
      sample_rate: 44100,
      cps: 2.0,
      samples_path: fixtures_path
    )
    pat = dsl.s("unpitched_test").release(0.1)
    cyclist.set_pattern(pat)

    cyclist.generate(256)

    active = cyclist.instance_variable_get(:@active_players)
    assert active.length > 0, "Should have at least one active player"

    player = active.first.player
    hold_duration = player.instance_variable_get(:@hold_duration)
    refute_nil hold_duration,
      "hold_duration should be set when release is explicitly specified"
  end

  it "applies Strudel-like pan curve (cos/sin) to stereo output" do
    dsl = Object.new.extend(Strudel::DSL)

    cyclist = Strudel::Scheduler::Cyclist.new(sample_rate: 1000, cps: 1.0)
    pat = dsl.n("0*4").scale("c:major").s("sine").gain(0.01).pan(0.25)
    cyclist.set_pattern(pat)

    left, right = cyclist.generate(200)

    avg_l = left.map(&:abs).sum / left.length
    avg_r = right.map(&:abs).sum / right.length
    ratio = avg_l / avg_r

    expected = Math.cos(Math::PI / 8.0) / Math.sin(Math::PI / 8.0)
    assert_in_delta expected, ratio, 0.1
  end
end
