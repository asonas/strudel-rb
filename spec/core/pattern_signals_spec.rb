# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::DSL do
  include Strudel::DSL

  # Phase 3.1
  describe "#tri" do
    it "returns 0 at cycle start" do
      pattern = tri.segment(4)
      haps = pattern.query_arc(0, 1)

      assert_in_delta 0.0, haps[0].value, 0.01
    end

    it "returns 1 at cycle midpoint" do
      pattern = tri.segment(4)
      haps = pattern.query_arc(0, 1)

      # segment(4) samples at 0, 0.25, 0.5, 0.75
      # tri at 0.25 should be 0.5, at 0.5 should be 1.0
      assert_in_delta 0.5, haps[1].value, 0.01
      assert_in_delta 1.0, haps[2].value, 0.01
    end

    it "returns to 0 at cycle end" do
      pattern = tri.segment(4)
      haps = pattern.query_arc(0, 1)

      # tri at 0.75 should be 0.5
      assert_in_delta 0.5, haps[3].value, 0.01
    end
  end

  describe "#saw" do
    it "ramps from 0 to 1 across a cycle" do
      pattern = saw.segment(4)
      haps = pattern.query_arc(0, 1)

      assert_in_delta 0.0, haps[0].value, 0.01
      assert_in_delta 0.25, haps[1].value, 0.01
      assert_in_delta 0.5, haps[2].value, 0.01
      assert_in_delta 0.75, haps[3].value, 0.01
    end
  end

  describe "#sine" do
    it "oscillates between 0 and 1" do
      pattern = sine.segment(4)
      haps = pattern.query_arc(0, 1)

      # sine: (1 + sin(2*pi*t)) / 2
      # t=0: 0.5, t=0.25: 1.0, t=0.5: 0.5, t=0.75: 0.0
      assert_in_delta 0.5, haps[0].value, 0.01
      assert_in_delta 1.0, haps[1].value, 0.01
      assert_in_delta 0.5, haps[2].value, 0.01
      assert_in_delta 0.0, haps[3].value, 0.01
    end
  end

  describe "#square" do
    it "alternates between 0 and 1" do
      pattern = square.segment(4)
      haps = pattern.query_arc(0, 1)

      # square: 1 for first half, 0 for second half
      assert_in_delta 1.0, haps[0].value, 0.01
      assert_in_delta 1.0, haps[1].value, 0.01
      assert_in_delta 0.0, haps[2].value, 0.01
      assert_in_delta 0.0, haps[3].value, 0.01
    end
  end

  # Phase 3.2
  describe "Pattern#range" do
    it "scales 0-1 values to min-max range" do
      # Use saw which goes 0, 0.25, 0.5, 0.75
      pattern = saw.segment(4).range(40, 52)
      haps = pattern.query_arc(0, 1)

      assert_in_delta 40.0, haps[0].value, 0.01
      assert_in_delta 43.0, haps[1].value, 0.01
      assert_in_delta 46.0, haps[2].value, 0.01
      assert_in_delta 49.0, haps[3].value, 0.01
    end
  end
end
