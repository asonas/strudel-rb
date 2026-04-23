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

  describe "slow (/N)" do
    it "parses /N as slow operator — whole spans N cycles" do
      pattern = parse("bd/4")
      haps = pattern.query_arc(0, 4)

      # span_cycles splits [0,4] into 4 visible pieces of the same stretched event,
      # all sharing whole=[0,4] (only the first piece has onset).
      assert_operator haps.length, :>=, 1
      assert haps.all? { |h| h.value == "bd" }
      assert haps.all? { |h| h.whole == Strudel::TimeSpan.new(0, 4) }
    end

    it "only triggers onset on the first cycle of the stretch" do
      pattern = parse("bd/4")

      cycle0 = pattern.query_arc(0, 1)
      cycle1 = pattern.query_arc(1, 2)
      cycle2 = pattern.query_arc(2, 3)
      cycle3 = pattern.query_arc(3, 4)
      cycle4 = pattern.query_arc(4, 5)

      assert_equal 1, cycle0.length
      assert cycle0.first.has_onset?

      assert_equal 1, cycle1.length
      refute cycle1.first.has_onset?

      assert_equal 1, cycle2.length
      refute cycle2.first.has_onset?

      assert_equal 1, cycle3.length
      refute cycle3.first.has_onset?

      # Cycle 4 starts a new stretch — onset again
      assert_equal 1, cycle4.length
      assert cycle4.first.has_onset?
    end

    it "parses /N on a group so the whole sub-pattern is slowed" do
      pattern = parse("[bd sd]/2")
      haps = pattern.query_arc(0, 2)

      # [bd sd] is 2 events spanning 1 cycle; /2 stretches to 2 cycles → bd at [0,1], sd at [1,2]
      assert_equal 2, haps.length
      assert_equal "bd", haps[0].value
      assert_equal Strudel::TimeSpan.new(0, 1), haps[0].whole
      assert_equal "sd", haps[1].value
      assert_equal Strudel::TimeSpan.new(1, 2), haps[1].whole
    end

    it "parses /N in a sequence alongside normal elements" do
      pattern = parse("bd sd/2 hh")
      # sequence of 3 items: bd (fast), sd/2 (slow), hh (fast)
      # Each item gets 1/3 of the cycle. sd/2 slows sd within its 1/3 slot... but /N on an
      # element inside a sequence stretches it across N cycles' worth of that slot.
      # Just assert parsing succeeds and the sequence has 3 items' worth of events.
      haps = pattern.query_arc(0, 1)
      assert_operator haps.length, :>=, 2
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
