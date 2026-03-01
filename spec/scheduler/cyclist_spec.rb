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
