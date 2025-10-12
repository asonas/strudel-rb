# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Hap do
  describe "#initialize" do
    it "creates a hap with whole, part, and value" do
      whole = Strudel::TimeSpan.new(0, 1)
      part = Strudel::TimeSpan.new(0, 1)
      hap = Strudel::Hap.new(whole, part, "bd")

      assert_equal whole, hap.whole
      assert_equal part, hap.part
      assert_equal "bd", hap.value
    end

    it "creates a hap with nil whole (continuous)" do
      part = Strudel::TimeSpan.new(0, 1)
      hap = Strudel::Hap.new(nil, part, 0.5)

      assert_nil hap.whole
      assert_equal part, hap.part
      assert_equal 0.5, hap.value
    end

    it "creates a hap with context" do
      whole = Strudel::TimeSpan.new(0, 1)
      part = Strudel::TimeSpan.new(0, 1)
      context = { source: "test" }
      hap = Strudel::Hap.new(whole, part, "bd", context)

      assert_equal context, hap.context
    end
  end

  describe "#has_onset?" do
    it "returns true when part begins at whole's beginning" do
      whole = Strudel::TimeSpan.new(0, 1)
      part = Strudel::TimeSpan.new(0, Rational(1, 2))
      hap = Strudel::Hap.new(whole, part, "bd")

      assert hap.has_onset?
    end

    it "returns false when part begins after whole's beginning" do
      whole = Strudel::TimeSpan.new(0, 1)
      part = Strudel::TimeSpan.new(Rational(1, 4), Rational(3, 4))
      hap = Strudel::Hap.new(whole, part, "bd")

      refute hap.has_onset?
    end

    it "returns false when whole is nil (continuous)" do
      part = Strudel::TimeSpan.new(0, 1)
      hap = Strudel::Hap.new(nil, part, 0.5)

      refute hap.has_onset?
    end
  end

  describe "#with_value" do
    it "returns new hap with transformed value" do
      whole = Strudel::TimeSpan.new(0, 1)
      part = Strudel::TimeSpan.new(0, 1)
      hap = Strudel::Hap.new(whole, part, "bd")

      new_hap = hap.with_value { |v| { s: v } }

      assert_equal({ s: "bd" }, new_hap.value)
      assert_equal whole, new_hap.whole
      assert_equal part, new_hap.part
    end
  end

  describe "#with_span" do
    it "returns new hap with transformed spans" do
      whole = Strudel::TimeSpan.new(0, 1)
      part = Strudel::TimeSpan.new(0, 1)
      hap = Strudel::Hap.new(whole, part, "bd")

      new_hap = hap.with_span { |span| span.with_time { |t| t * 2 } }

      assert_equal Strudel::TimeSpan.new(0, 2), new_hap.whole
      assert_equal Strudel::TimeSpan.new(0, 2), new_hap.part
    end
  end

  describe "#duration" do
    it "returns whole duration when whole exists" do
      whole = Strudel::TimeSpan.new(0, 1)
      part = Strudel::TimeSpan.new(0, Rational(1, 2))
      hap = Strudel::Hap.new(whole, part, "bd")

      assert_equal Strudel::Fraction.new(1), hap.duration
    end

    it "returns part duration when whole is nil" do
      part = Strudel::TimeSpan.new(0, Rational(1, 2))
      hap = Strudel::Hap.new(nil, part, "bd")

      assert_equal Strudel::Fraction.new(Rational(1, 2)), hap.duration
    end
  end
end
