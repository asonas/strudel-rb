# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::Reverb do
  describe "#process" do
    it "returns dry signal when wet is 0" do
      reverb = Strudel::Audio::Reverb.new(sample_rate: 44_100)
      reverb.configure(wet: 0.0, roomsize: 1.0)

      input_l = Array.new(100, 0.0)
      input_r = Array.new(100, 0.0)
      input_l[0] = 1.0
      input_r[0] = 1.0

      out_l, out_r = reverb.process(input_l, input_r)

      assert_equal 100, out_l.length
      assert_equal 100, out_r.length
      assert_in_delta 1.0, out_l[0], 0.01
      assert_in_delta 1.0, out_r[0], 0.01
    end

    it "adds reverb tail when wet is 1" do
      reverb = Strudel::Audio::Reverb.new(sample_rate: 44_100)
      reverb.configure(wet: 1.0, roomsize: 2.0)

      # Impulse input
      input_l = Array.new(4410, 0.0)
      input_r = Array.new(4410, 0.0)
      input_l[0] = 1.0
      input_r[0] = 1.0

      out_l, out_r = reverb.process(input_l, input_r)

      # With reverb, samples after the impulse should be non-zero
      tail_energy = out_l[100..].sum { |s| s * s }
      assert tail_energy > 0.0, "Reverb should produce a tail"
    end

    it "produces finite output" do
      reverb = Strudel::Audio::Reverb.new(sample_rate: 44_100)
      reverb.configure(wet: 0.5, roomsize: 5.0)

      input_l = Array.new(4410, 0.0)
      input_r = Array.new(4410, 0.0)
      input_l[0] = 1.0
      input_r[0] = 1.0

      out_l, out_r = reverb.process(input_l, input_r)

      assert out_l.all?(&:finite?), "All reverb output should be finite"
      assert out_r.all?(&:finite?), "All reverb output should be finite"
    end

    it "longer roomsize produces longer tail" do
      reverb_short = Strudel::Audio::Reverb.new(sample_rate: 44_100)
      reverb_short.configure(wet: 1.0, roomsize: 0.5)

      reverb_long = Strudel::Audio::Reverb.new(sample_rate: 44_100)
      reverb_long.configure(wet: 1.0, roomsize: 5.0)

      input_l = Array.new(4410, 0.0)
      input_r = Array.new(4410, 0.0)
      input_l[0] = 1.0
      input_r[0] = 1.0

      out_short_l, _ = reverb_short.process(input_l.dup, input_r.dup)
      out_long_l, _ = reverb_long.process(input_l.dup, input_r.dup)

      # Measure energy in the late part of the reverb tail
      late_energy_short = out_short_l[2000..].sum { |s| s * s }
      late_energy_long = out_long_l[2000..].sum { |s| s * s }

      assert late_energy_long > late_energy_short, "Longer roomsize should produce more late energy"
    end
  end

  describe "#configure" do
    it "updates wet and roomsize" do
      reverb = Strudel::Audio::Reverb.new(sample_rate: 44_100)
      reverb.configure(wet: 0.7, roomsize: 3.0)

      assert_in_delta 0.7, reverb.wet, 0.001
      assert_in_delta 3.0, reverb.roomsize, 0.001
    end
  end
end
