# frozen_string_literal: true

require_relative "spec_helper"

describe Strudel::DSL do
  include Strudel::DSL

  describe "#note" do
    it "parses note names to MIDI numbers" do
      pattern = note("c4")
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal 60, haps.first.value[:note]
    end

    it "parses sharps and flats" do
      pattern = note("c#4 db4")
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal 61, haps[0].value[:note]
      assert_equal 61, haps[1].value[:note]
    end

    it "handles different octaves" do
      pattern = note("a3 a4 a5")
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.length
      assert_equal 57, haps[0].value[:note] # A3
      assert_equal 69, haps[1].value[:note] # A4 (concert pitch)
      assert_equal 81, haps[2].value[:note] # A5
    end

    it "passes through numeric values" do
      pattern = note("60 64 67")
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.length
      assert_equal 60, haps[0].value[:note]
      assert_equal 64, haps[1].value[:note]
      assert_equal 67, haps[2].value[:note]
    end
  end

  describe "#gain" do
    it "creates a gain control pattern" do
      pattern = sound("bd").gain(gain("1 2"))
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal 1.0, haps[0].value[:gain]
      assert_equal 2.0, haps[1].value[:gain]
    end
  end

  describe "#speed" do
    it "creates a speed control pattern" do
      pattern = sound("breaks").speed(speed("1 2"))
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal 1.0, haps[0].value[:speed]
      assert_equal 2.0, haps[1].value[:speed]
    end
  end

  describe "#pan" do
    it "creates a pan control pattern" do
      pattern = sound("bd").pan(pan("0 1"))
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal 0.0, haps[0].value[:pan]
      assert_equal 1.0, haps[1].value[:pan]
    end
  end

  describe "#euclid" do
    it "creates euclidean rhythm pattern" do
      pattern = euclid(3, 8)
      haps = pattern.query_arc(0, 1)

      # 3 hits in 8 steps = x..x..x.
      assert_equal 3, haps.length
    end

    it "creates classic tresillo rhythm" do
      pattern = euclid(3, 8)
      haps = pattern.query_arc(0, 1)

      # Positions: 0/8, 3/8, 6/8
      assert_equal Rational(0, 8), haps[0].whole.begin_time.value
      assert_equal Rational(3, 8), haps[1].whole.begin_time.value
      assert_equal Rational(6, 8), haps[2].whole.begin_time.value
    end
  end

  describe "#pure" do
    it "creates a pure pattern" do
      pattern = pure("bd")
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal "bd", haps.first.value
    end
  end

  describe "#cat" do
    it "is an alias for fastcat" do
      pattern = cat(pure("bd"), pure("sd"))
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "sd", haps[1].value
    end
  end
end
