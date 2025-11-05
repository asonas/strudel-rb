# frozen_string_literal: true

module Strudel
  class Fraction
    include Comparable

    attr_reader :value

    def initialize(value)
      @value = value.is_a?(Rational) ? value : Rational(value)
    end

    # Cycle start time (floor)
    def sam
      Fraction.new(@value.floor)
    end

    # Next cycle start time
    def next_sam
      sam + Fraction.new(1)
    end

    # Relative position within the cycle
    def cycle_pos
      self - sam
    end

    # TimeSpan for the entire cycle
    def whole_cycle
      TimeSpan.new(sam, next_sam)
    end

    # Arithmetic operations
    def +(other)
      other_value = other.is_a?(Fraction) ? other.value : Rational(other)
      Fraction.new(@value + other_value)
    end

    def -(other)
      other_value = other.is_a?(Fraction) ? other.value : Rational(other)
      Fraction.new(@value - other_value)
    end

    def *(other)
      other_value = other.is_a?(Fraction) ? other.value : Rational(other)
      Fraction.new(@value * other_value)
    end

    def /(other)
      other_value = other.is_a?(Fraction) ? other.value : Rational(other)
      Fraction.new(@value / other_value)
    end

    # Comparison operations
    def <=>(other)
      other_value = other.is_a?(Fraction) ? other.value : Rational(other)
      @value <=> other_value
    end

    def ==(other)
      return false unless other.is_a?(Fraction)

      @value == other.value
    end

    def eql?(other)
      self == other
    end

    def hash
      @value.hash
    end

    # Conversion
    def to_f
      @value.to_f
    end

    def to_r
      @value
    end

    def to_i
      @value.to_i
    end

    def floor
      Fraction.new(@value.floor)
    end

    def ceil
      Fraction.new(@value.ceil)
    end

    def inspect
      "Fraction(#{@value})"
    end
  end
end
