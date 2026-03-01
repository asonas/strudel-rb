# frozen_string_literal: true

require_relative "spec_helper"

describe Strudel::DSL do
  include Strudel::DSL

  # Phase 5.1
  describe "#rlpf" do
    it "applies normalized low-pass filter" do
      # rlpf(0.5) should set lpf to (0.5 * 12)^4 = 6^4 = 1296
      pattern = Strudel::Pattern.pure({ s: "bd" }).rlpf(0.5)
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_in_delta 1296, haps.first.value[:lpf], 1
    end

    it "rlpf(1) applies maximum cutoff" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).rlpf(1)
      haps = pattern.query_arc(0, 1)

      # (1 * 12)^4 = 20736
      assert_in_delta 20736, haps.first.value[:lpf], 1
    end
  end

  # Phase 5.2
  describe "#rhpf" do
    it "applies normalized high-pass filter" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).rhpf(0.5)
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_in_delta 1296, haps.first.value[:hpf], 1
    end
  end

  # Phase 5.3
  describe "#trancegate" do
    it "creates a gated pattern" do
      pattern = Strudel::Pattern.pure({ s: "pad" }).trancegate(0.5, 0, 1)
      haps = pattern.query_arc(0, 1)

      # trancegate should produce some events (density-dependent)
      refute_empty haps
    end

    it "all events have clip control set" do
      pattern = Strudel::Pattern.pure({ s: "pad" }).trancegate(0.5, 0, 1)
      haps = pattern.query_arc(0, 1)

      haps.each do |h|
        assert_equal 0.7, h.value[:clip]
      end
    end
  end

  describe "#glide" do
    it "returns a Pattern" do
      pattern = Strudel::Pattern.pure({ note: 60, s: "supersaw" }).glide(0.03)
      assert_instance_of Strudel::Pattern, pattern
    end

    it "sets pdecay to glide time" do
      pattern = Strudel::Pattern.pure({ note: 60, s: "supersaw" }).glide(0.03)
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal 0.03, haps.first.value[:pdecay]
    end

    it "does not set penv when no previous notes exist" do
      pattern = Strudel::Pattern.pure({ note: 60, s: "supersaw" }).glide(0.03)
      haps = pattern.query_arc(0, 1)

      assert_nil haps.first.value[:penv]
    end

    it "calculates penv from previous note when ascending" do
      # Cycle 0: note 60 (C4), Cycle 1: note 64 (E4)
      # penv = -12 * log2(freq_64 / freq_60) = -4 semitones
      base = Strudel::Pattern.slowcat(
        Strudel::Pattern.pure({ note: 60, s: "supersaw" }),
        Strudel::Pattern.pure({ note: 64, s: "supersaw" })
      )
      pattern = base.glide(0.03)

      # First query: cycle 0 - no previous notes
      pattern.query_arc(0, 1)

      # Second query: cycle 1 - should have penv based on note 60 -> 64
      haps = pattern.query_arc(1, 2)
      assert_equal 1, haps.length
      # Ascending: penv is negative (start below target, glide up)
      assert_in_delta(-4.0, haps.first.value[:penv], 0.01)
    end

    it "calculates penv from previous note when descending" do
      # Cycle 0: note 64 (E4), Cycle 1: note 60 (C4)
      # penv = -12 * log2(freq_60 / freq_64) = +4 semitones
      base = Strudel::Pattern.slowcat(
        Strudel::Pattern.pure({ note: 64, s: "supersaw" }),
        Strudel::Pattern.pure({ note: 60, s: "supersaw" })
      )
      pattern = base.glide(0.05)

      pattern.query_arc(0, 1)
      haps = pattern.query_arc(1, 2)

      # Descending: penv is positive (start above target, glide down)
      assert_in_delta(4.0, haps.first.value[:penv], 0.01)
      assert_equal 0.05, haps.first.value[:pdecay]
    end
  end
end
