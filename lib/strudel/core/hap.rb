# frozen_string_literal: true

module Strudel
  class Hap
    attr_reader :whole, :part, :value, :context

    def initialize(whole, part, value, context = {})
      @whole = whole
      @part = part
      @value = value
      @context = context
    end

    # Whether this is an onset (part.begin matches whole.begin)
    def has_onset?
      return false if @whole.nil?

      @whole.begin_time == @part.begin_time
    end

    # Returns a new Hap with transformed value
    def with_value(&block)
      Hap.new(@whole, @part, block.call(@value), @context)
    end

    # Returns a new Hap with transformed time span
    def with_span(&block)
      new_whole = @whole ? block.call(@whole) : nil
      new_part = block.call(@part)
      Hap.new(new_whole, new_part, @value, @context)
    end

    # Event duration
    def duration
      (@whole || @part).duration
    end

    # Duration of the part
    def part_duration
      @part.duration
    end

    def ==(other)
      return false unless other.is_a?(Hap)

      @whole == other.whole &&
        @part == other.part &&
        @value == other.value
    end

    def eql?(other)
      self == other
    end

    def hash
      [@whole, @part, @value].hash
    end

    def inspect
      "Hap(whole: #{@whole&.inspect}, part: #{@part.inspect}, value: #{@value.inspect})"
    end
  end
end
