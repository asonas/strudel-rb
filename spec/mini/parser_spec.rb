# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Mini::Parser do
  def parse(input)
    Strudel::Mini::Parser.new.parse(input)
  end

  describe "single atom" do
    it "parses a single sound name" do
      pattern = parse("bd")
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal "bd", haps.first.value
    end

    it "parses a sound name with number suffix" do
      pattern = parse("hh:2")
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal({ s: "hh", n: 2 }, haps.first.value)
    end
  end

  describe "sequence" do
    it "parses space-separated sequence" do
      pattern = parse("bd sd")
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "sd", haps[1].value
    end

    it "parses four element sequence" do
      pattern = parse("bd hh sd hh")
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "hh", haps[1].value
      assert_equal "sd", haps[2].value
      assert_equal "hh", haps[3].value
    end
  end

  describe "rest" do
    it "parses rest with tilde" do
      pattern = parse("bd ~ sd ~")
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "sd", haps[1].value
    end

    it "parses rest with dash" do
      pattern = parse("bd - sd -")
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "sd", haps[1].value
    end
  end

  describe "elongate (_)" do
    it "extends the duration of the previous event by one step" do
      pattern = parse("bd _ _ ~ sd _")
      haps = pattern.query_arc(0, 1)

      bd = haps.find { |h| h.value == "bd" }
      assert_equal Strudel::TimeSpan.new(0, Rational(1, 2)), bd.whole

      sd = haps.find { |h| h.value == "sd" }
      assert_equal Strudel::TimeSpan.new(Rational(4, 6), 1), sd.whole
    end
  end

  describe "subsequence" do
    it "parses bracketed subsequence" do
      pattern = parse("bd [hh hh]")
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "hh", haps[1].value
      assert_equal "hh", haps[2].value

      # bd takes first half, [hh hh] takes second half
      assert_equal Strudel::TimeSpan.new(0, Rational(1, 2)), haps[0].whole
      assert_equal Strudel::TimeSpan.new(Rational(1, 2), Rational(3, 4)), haps[1].whole
      assert_equal Strudel::TimeSpan.new(Rational(3, 4), 1), haps[2].whole
    end

    it "parses nested subsequence" do
      pattern = parse("[bd [hh sd]]")
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "hh", haps[1].value
      assert_equal "sd", haps[2].value
    end
  end

  describe "multiplication" do
    it "parses multiplication" do
      pattern = parse("bd*2")
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "bd", haps[1].value
    end

    it "parses multiplication in sequence" do
      pattern = parse("bd hh*2 sd")
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "hh", haps[1].value
      assert_equal "hh", haps[2].value
      assert_equal "sd", haps[3].value
    end

    it "parses subsequence multiplication" do
      pattern = parse("[bd sd]*2")
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "sd", haps[1].value
      assert_equal "bd", haps[2].value
      assert_equal "sd", haps[3].value
    end
  end

  describe "replicate (!)" do
    it "replicates a step and increases the number of steps" do
      pattern = parse("bd!3 sd")
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
      assert_equal %w[bd bd bd sd], haps.map(&:value)

      assert_equal Strudel::TimeSpan.new(0, Rational(1, 4)), haps[0].whole
      assert_equal Strudel::TimeSpan.new(Rational(3, 4), 1), haps[3].whole
    end
  end

  describe "stack (parallel)" do
    it "parses comma-separated stack" do
      pattern = parse("bd, hh")
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      values = haps.map(&:value)
      assert_includes values, "bd"
      assert_includes values, "hh"
    end

    it "parses stack with sequences" do
      pattern = parse("bd sd, hh hh hh")
      haps = pattern.query_arc(0, 1)

      assert_equal 5, haps.length
    end
  end

  describe "angle brackets (slowcat)" do
    it "parses angle brackets as one-per-cycle" do
      pattern = parse("<bd sd hh>")

      haps0 = pattern.query_arc(0, 1)
      assert_equal 1, haps0.length
      assert_equal "bd", haps0.first.value

      haps1 = pattern.query_arc(1, 2)
      assert_equal 1, haps1.length
      assert_equal "sd", haps1.first.value

      haps2 = pattern.query_arc(2, 3)
      assert_equal 1, haps2.length
      assert_equal "hh", haps2.first.value
    end

    it "treats _ as hold (repeat previous cycle) inside slowcat" do
      pattern = parse("<7 _ _ 6>")
      haps = pattern.query_arc(0, 4)

      assert_equal 4, haps.length
      assert_equal %w[7 7 7 6], haps.map(&:value)

      assert_equal Strudel::TimeSpan.new(0, 1), haps[0].whole
      assert_equal Strudel::TimeSpan.new(1, 2), haps[1].whole
      assert_equal Strudel::TimeSpan.new(2, 3), haps[2].whole
      assert_equal Strudel::TimeSpan.new(3, 4), haps[3].whole
    end

    it "supports fast (*n) by pulling values from subsequent cycles" do
      pattern = parse("<bd sd hh>*4")
      haps0 = pattern.query_arc(0, 1)

      assert_equal 4, haps0.length
      assert_equal %w[bd sd hh bd], haps0.map(&:value)
    end

    it "keeps step count at n for <...>*n (not elements*n)" do
      pattern = parse("<0 4 0 9 7>*16")
      haps0 = pattern.query_arc(0, 1)

      assert_equal 16, haps0.length
      assert_equal(
        %w[0 4 0 9 7 0 4 0 9 7 0 4 0 9 7 0],
        haps0.map(&:value)
      )
    end
  end
end
