# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Pattern do
  describe "#chop" do
    it "splits a single hap into n sub-haps in one cycle" do
      pat = Strudel::Pattern.pure(s: "x").chop(4)
      haps = pat.query_arc(0, 1)

      assert_equal 4, haps.length
    end

    it "assigns begin/end fractions of [i/n, (i+1)/n] to each sub-hap" do
      pat = Strudel::Pattern.pure(s: "x").chop(4)
      haps = pat.query_arc(0, 1)

      expected = [
        [Rational(0, 4), Rational(1, 4)],
        [Rational(1, 4), Rational(2, 4)],
        [Rational(2, 4), Rational(3, 4)],
        [Rational(3, 4), Rational(4, 4)],
      ]
      actual = haps.map { |h| [h.value[:begin], h.value[:end]] }
      assert_equal expected, actual
    end

    it "divides the original whole duration evenly across sub-haps" do
      pat = Strudel::Pattern.pure(s: "x").chop(4)
      haps = pat.query_arc(0, 1)

      durations = haps.map { |h| h.whole.duration.value }
      assert_equal [Rational(1, 4)] * 4, durations
    end

    it "returns the input unchanged for chop(1)" do
      pat = Strudel::Pattern.pure(s: "x").chop(1)
      haps = pat.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_nil haps.first.value[:begin]
      assert_nil haps.first.value[:end]
    end

    it "wraps a non-Hash value into {s: value, begin:, end:}" do
      pat = Strudel::Pattern.pure("x").chop(2)
      haps = pat.query_arc(0, 1)

      assert_equal "x", haps.first.value[:s]
      assert_equal Rational(0, 2), haps.first.value[:begin]
      assert_equal Rational(1, 2), haps.first.value[:end]
    end

    it "accepts a Pattern for n so cycles can have different slice counts" do
      # <4 2> slowcat: cycle 0 uses 4, cycle 1 uses 2
      n_pat = Strudel::Mini::Parser.new.parse("<4 2>").with_value { |v| v.to_i }
      pat = Strudel::Pattern.pure(s: "x").chop(n_pat)

      cycle0 = pat.query_arc(0, 1)
      cycle1 = pat.query_arc(1, 2)

      assert_equal 4, cycle0.length
      assert_equal 2, cycle1.length
    end
  end
end
