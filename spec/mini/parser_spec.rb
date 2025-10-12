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
  end
end
