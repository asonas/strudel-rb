# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Fraction do
  describe "#initialize" do
    it "creates from integer" do
      f = Strudel::Fraction.new(3)
      assert_equal Rational(3), f.value
    end

    it "creates from float" do
      f = Strudel::Fraction.new(0.5)
      assert_equal Rational(1, 2), f.value
    end

    it "creates from Rational" do
      f = Strudel::Fraction.new(Rational(1, 3))
      assert_equal Rational(1, 3), f.value
    end
  end

  describe "#sam" do
    it "returns cycle start for integer" do
      f = Strudel::Fraction.new(3)
      assert_equal Strudel::Fraction.new(3), f.sam
    end

    it "returns cycle start for fractional value" do
      f = Strudel::Fraction.new(Rational(5, 2))  # 2.5
      assert_equal Strudel::Fraction.new(2), f.sam
    end

    it "returns 0 for values between 0 and 1" do
      f = Strudel::Fraction.new(Rational(1, 3))
      assert_equal Strudel::Fraction.new(0), f.sam
    end
  end

  describe "#next_sam" do
    it "returns next cycle start" do
      f = Strudel::Fraction.new(Rational(5, 2))  # 2.5
      assert_equal Strudel::Fraction.new(3), f.next_sam
    end

    it "returns 1 for values between 0 and 1" do
      f = Strudel::Fraction.new(Rational(1, 3))
      assert_equal Strudel::Fraction.new(1), f.next_sam
    end
  end

  describe "#cycle_pos" do
    it "returns position within cycle" do
      f = Strudel::Fraction.new(Rational(5, 2))  # 2.5
      assert_equal Strudel::Fraction.new(Rational(1, 2)), f.cycle_pos
    end

    it "returns same value for values between 0 and 1" do
      f = Strudel::Fraction.new(Rational(1, 3))
      assert_equal Strudel::Fraction.new(Rational(1, 3)), f.cycle_pos
    end
  end

  describe "arithmetic operations" do
    it "adds fractions" do
      a = Strudel::Fraction.new(Rational(1, 2))
      b = Strudel::Fraction.new(Rational(1, 3))
      assert_equal Strudel::Fraction.new(Rational(5, 6)), a + b
    end

    it "subtracts fractions" do
      a = Strudel::Fraction.new(Rational(1, 2))
      b = Strudel::Fraction.new(Rational(1, 3))
      assert_equal Strudel::Fraction.new(Rational(1, 6)), a - b
    end

    it "multiplies fractions" do
      a = Strudel::Fraction.new(Rational(1, 2))
      b = Strudel::Fraction.new(Rational(1, 3))
      assert_equal Strudel::Fraction.new(Rational(1, 6)), a * b
    end

    it "divides fractions" do
      a = Strudel::Fraction.new(Rational(1, 2))
      b = Strudel::Fraction.new(Rational(1, 3))
      assert_equal Strudel::Fraction.new(Rational(3, 2)), a / b
    end
  end

  describe "comparison operations" do
    it "compares equal fractions" do
      a = Strudel::Fraction.new(Rational(1, 2))
      b = Strudel::Fraction.new(Rational(1, 2))
      assert_equal a, b
    end

    it "compares less than" do
      a = Strudel::Fraction.new(Rational(1, 3))
      b = Strudel::Fraction.new(Rational(1, 2))
      assert a < b
    end

    it "compares greater than" do
      a = Strudel::Fraction.new(Rational(1, 2))
      b = Strudel::Fraction.new(Rational(1, 3))
      assert a > b
    end
  end

  describe "#to_f" do
    it "converts to float" do
      f = Strudel::Fraction.new(Rational(1, 2))
      assert_equal 0.5, f.to_f
    end
  end
end
