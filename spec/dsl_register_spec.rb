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
end
