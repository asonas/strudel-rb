# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::TimeSpan do
  describe "#initialize" do
    it "creates from Fractions" do
      ts = Strudel::TimeSpan.new(
        Strudel::Fraction.new(0),
        Strudel::Fraction.new(1)
      )
      assert_equal Strudel::Fraction.new(0), ts.begin_time
      assert_equal Strudel::Fraction.new(1), ts.end_time
    end

    it "creates from numbers" do
      ts = Strudel::TimeSpan.new(0, 1)
      assert_equal Strudel::Fraction.new(0), ts.begin_time
      assert_equal Strudel::Fraction.new(1), ts.end_time
    end
  end

  describe "#duration" do
    it "returns the duration" do
      ts = Strudel::TimeSpan.new(0, 1)
      assert_equal Strudel::Fraction.new(1), ts.duration
    end

    it "returns fractional duration" do
      ts = Strudel::TimeSpan.new(Rational(1, 4), Rational(3, 4))
      assert_equal Strudel::Fraction.new(Rational(1, 2)), ts.duration
    end
  end

  describe "#span_cycles" do
    it "returns single span for span within one cycle" do
      ts = Strudel::TimeSpan.new(Rational(1, 4), Rational(3, 4))
      cycles = ts.span_cycles
      assert_equal 1, cycles.length
      assert_equal ts, cycles.first
    end

    it "returns single span for exact cycle" do
      ts = Strudel::TimeSpan.new(0, 1)
      cycles = ts.span_cycles
      assert_equal 1, cycles.length
      assert_equal ts, cycles.first
    end

    it "splits span across two cycles" do
      ts = Strudel::TimeSpan.new(Rational(1, 2), Rational(3, 2))
      cycles = ts.span_cycles
      assert_equal 2, cycles.length
      assert_equal Strudel::TimeSpan.new(Rational(1, 2), 1), cycles[0]
      assert_equal Strudel::TimeSpan.new(1, Rational(3, 2)), cycles[1]
    end

    it "splits span across three cycles" do
      ts = Strudel::TimeSpan.new(Rational(1, 2), Rational(5, 2))
      cycles = ts.span_cycles
      assert_equal 3, cycles.length
      assert_equal Strudel::TimeSpan.new(Rational(1, 2), 1), cycles[0]
      assert_equal Strudel::TimeSpan.new(1, 2), cycles[1]
      assert_equal Strudel::TimeSpan.new(2, Rational(5, 2)), cycles[2]
    end
  end

  describe "#intersection" do
    it "returns intersection when spans overlap" do
      ts1 = Strudel::TimeSpan.new(0, Rational(3, 4))
      ts2 = Strudel::TimeSpan.new(Rational(1, 4), 1)
      intersection = ts1.intersection(ts2)
      assert_equal Strudel::TimeSpan.new(Rational(1, 4), Rational(3, 4)), intersection
    end

    it "returns nil when spans do not overlap" do
      ts1 = Strudel::TimeSpan.new(0, Rational(1, 4))
      ts2 = Strudel::TimeSpan.new(Rational(1, 2), 1)
      assert_nil ts1.intersection(ts2)
    end

    it "returns nil when spans are adjacent" do
      ts1 = Strudel::TimeSpan.new(0, Rational(1, 2))
      ts2 = Strudel::TimeSpan.new(Rational(1, 2), 1)
      assert_nil ts1.intersection(ts2)
    end

    it "returns self when other contains self" do
      ts1 = Strudel::TimeSpan.new(Rational(1, 4), Rational(3, 4))
      ts2 = Strudel::TimeSpan.new(0, 1)
      intersection = ts1.intersection(ts2)
      assert_equal ts1, intersection
    end
  end

  describe "#midpoint" do
    it "returns the midpoint" do
      ts = Strudel::TimeSpan.new(0, 1)
      assert_equal Strudel::Fraction.new(Rational(1, 2)), ts.midpoint
    end
  end

  describe "#==" do
    it "returns true for equal spans" do
      ts1 = Strudel::TimeSpan.new(0, 1)
      ts2 = Strudel::TimeSpan.new(0, 1)
      assert_equal ts1, ts2
    end

    it "returns false for different spans" do
      ts1 = Strudel::TimeSpan.new(0, 1)
      ts2 = Strudel::TimeSpan.new(0, 2)
      refute_equal ts1, ts2
    end
  end

  describe "#cycle_arc" do
    it "returns arc within first cycle" do
      ts = Strudel::TimeSpan.new(Rational(1, 4), Rational(3, 4))
      arc = ts.cycle_arc
      assert_equal Strudel::TimeSpan.new(Rational(1, 4), Rational(3, 4)), arc
    end

    it "returns arc normalized to cycle position for later cycle" do
      ts = Strudel::TimeSpan.new(Rational(5, 4), Rational(7, 4))
      arc = ts.cycle_arc
      assert_equal Strudel::TimeSpan.new(Rational(1, 4), Rational(3, 4)), arc
    end
  end
end
