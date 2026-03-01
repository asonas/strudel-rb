# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Pattern do
  # Phase 2.1
  describe "#mask" do
    it "passes through events where mask is 1" do
      pattern = Strudel::Pattern.fastcat("bd", "sd").mask(
        Strudel::Pattern.fastcat(1, 1)
      )
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "sd", haps[1].value
    end

    it "removes events where mask is 0" do
      pattern = Strudel::Pattern.fastcat("bd", "sd", "hh", "cp").mask(
        Strudel::Pattern.fastcat(1, 0, 1, 0)
      )
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "hh", haps[1].value
    end

    it "preserves original pattern timing (whole)" do
      pattern = Strudel::Pattern.fastcat("bd", "sd").mask(
        Strudel::Pattern.fastcat(1, 0)
      )
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      # whole should come from the original pattern, not the mask
      assert_equal Strudel::TimeSpan.new(0, Rational(1, 2)), haps[0].whole
    end
  end

  # Phase 2.2
  describe "#segment" do
    it "samples a continuous pattern into n discrete events" do
      pattern = Strudel::Pattern.pure(42).segment(4)
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
      haps.each { |h| assert_equal 42, h.value }
    end

    it "each segment has correct timing" do
      pattern = Strudel::Pattern.pure(1).segment(4)
      haps = pattern.query_arc(0, 1)

      assert_equal Strudel::TimeSpan.new(0, Rational(1, 4)), haps[0].whole
      assert_equal Strudel::TimeSpan.new(Rational(1, 4), Rational(2, 4)), haps[1].whole
      assert_equal Strudel::TimeSpan.new(Rational(2, 4), Rational(3, 4)), haps[2].whole
      assert_equal Strudel::TimeSpan.new(Rational(3, 4), 1), haps[3].whole
    end

    it "has seg alias" do
      pattern = Strudel::Pattern.pure(1).seg(4)
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
    end
  end

  # Phase 2.3
  describe "#ribbon" do
    it "loops a section of the pattern" do
      # slowcat plays a, b, c, d one per cycle
      # ribbon(1, 2) should loop cycles 1-2 (b, c) forever
      pattern = Strudel::Pattern.slowcat("a", "b", "c", "d").ribbon(1, 2)

      # Cycle 0 queries offset 1 => "b"
      haps0 = pattern.query_arc(0, 1)
      assert_equal "b", haps0.first.value

      # Cycle 1 queries offset 2 => "c"
      haps1 = pattern.query_arc(1, 2)
      assert_equal "c", haps1.first.value

      # Cycle 2 wraps back to offset 1 => "b"
      haps2 = pattern.query_arc(2, 3)
      assert_equal "b", haps2.first.value
    end

    it "has rib alias" do
      pattern = Strudel::Pattern.slowcat("a", "b", "c").rib(0, 2)
      haps = pattern.query_arc(0, 1)

      assert_equal "a", haps.first.value
    end
  end

  # Phase 2.4
  describe "#inner_join" do
    it "flattens a Pattern of Patterns" do
      # Create a pattern whose value is another pattern
      outer = Strudel::Pattern.pure(Strudel::Pattern.pure("hello"))
      flattened = outer.inner_join
      haps = flattened.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal "hello", haps.first.value
    end

    it "uses outer hap timing to constrain inner pattern" do
      # fmap creates a Pattern<Pattern<String>>
      outer = Strudel::Pattern.fastcat("a", "b").fmap do |v|
        Strudel::Pattern.pure(v.upcase)
      end
      flattened = outer.inner_join
      haps = flattened.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal "A", haps[0].value
      assert_equal "B", haps[1].value
    end
  end

  # Phase 2.5
  describe "#ply" do
    it "repeats each event n times" do
      pattern = Strudel::Pattern.fastcat("bd", "sd").ply(2)
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "bd", haps[1].value
      assert_equal "sd", haps[2].value
      assert_equal "sd", haps[3].value
    end

    it "subdivides event timing" do
      pattern = Strudel::Pattern.pure("bd").ply(3)
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.length
      assert_equal Strudel::TimeSpan.new(0, Rational(1, 3)), haps[0].whole
      assert_equal Strudel::TimeSpan.new(Rational(1, 3), Rational(2, 3)), haps[1].whole
      assert_equal Strudel::TimeSpan.new(Rational(2, 3), 1), haps[2].whole
    end
  end

  # Phase 2.6
  describe "#round" do
    it "rounds numeric values to nearest integer" do
      pattern = Strudel::Pattern.fastcat(
        Strudel::Pattern.pure(0.3),
        Strudel::Pattern.pure(1.7),
        Strudel::Pattern.pure(2.5)
      ).round
      haps = pattern.query_arc(0, 1)

      assert_equal 0, haps[0].value
      assert_equal 2, haps[1].value
      assert_equal 3, haps[2].value
    end
  end

  # Phase 2.7
  describe "#fill" do
    it "extends events to fill gaps" do
      # euclid(2,4) creates events at 0/4 and 2/4 with gaps at 1/4 and 3/4
      pattern = Strudel::Pattern.pure("bd").euclid(2, 4).fill
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      # First event should extend from 0 to 2/4 (filling the gap at 1/4)
      assert_equal Strudel::Fraction.new(0), haps[0].whole.begin_time
      assert_equal Strudel::Fraction.new(Rational(2, 4)), haps[0].whole.end_time
      # Second event should extend from 2/4 to 1 (filling the gap at 3/4)
      assert_equal Strudel::Fraction.new(Rational(2, 4)), haps[1].whole.begin_time
      assert_equal Strudel::Fraction.new(1), haps[1].whole.end_time
    end
  end

  # Phase 2.8
  describe "#beat" do
    it "places events at specified beat positions" do
      pattern = Strudel::Pattern.pure("bd").beat("0, 7, 10", 16)
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.length
      assert_equal Strudel::Fraction.new(Rational(0, 16)), haps[0].whole.begin_time
      assert_equal Strudel::Fraction.new(Rational(7, 16)), haps[1].whole.begin_time
      assert_equal Strudel::Fraction.new(Rational(10, 16)), haps[2].whole.begin_time
    end
  end

  # Phase 2.9
  describe "#scrub" do
    it "sets scrub control on pattern" do
      pattern = Strudel::Pattern.pure({ s: "miku" }).scrub(0.5)
      haps = pattern.query_arc(0, 1)

      assert_equal 0.5, haps.first.value[:scrub]
    end
  end

  # Phase 2.10
  describe "#restart" do
    it "restarts pattern at trigger onsets" do
      # A slow pattern that spans 4 cycles: a, b, c, d
      base = Strudel::Pattern.slowcat("a", "b", "c", "d")
      # Restart every cycle (trigger = pure(1) which has onset at 0 each cycle)
      restarted = base.restart(Strudel::Pattern.pure(1))

      # Every cycle should return "a" (cycle 0 value) because it restarts
      haps0 = restarted.query_arc(0, 1)
      assert_equal "a", haps0.first.value

      haps1 = restarted.query_arc(1, 2)
      assert_equal "a", haps1.first.value

      haps2 = restarted.query_arc(2, 3)
      assert_equal "a", haps2.first.value
    end
  end
end
