# frozen_string_literal: true

require "json"

module Strudel
  class Bridge
    # Evaluate a pattern over a time span and return JSON-serialized Haps
    #
    # @param pattern [Pattern] the pattern to evaluate
    # @param begin_time [Numeric, Fraction] the start of the time range
    # @param end_time [Numeric, Fraction] the end of the time range
    # @param cycle_offset [Numeric, Fraction] optional cycle offset (default: 0)
    # @return [String] JSON array of serialized Haps
    def self.evaluate(pattern, begin_time, end_time, cycle_offset = 0)
  begin_frac = begin_time.is_a?(Fraction) ? begin_time : Fraction.new(begin_time)
  end_frac = end_time.is_a?(Fraction) ? end_time : Fraction.new(end_time)

  # Create a TimeSpan for the query range
  span = TimeSpan.new(begin_frac, end_frac)
  state = State.new(span)
  haps = pattern.query(state)

  haps.map { |hap| serialize_hap(hap) }.to_json
end

    private

    # Serialize a single Hap to a Hash suitable for JSON encoding
    # @param hap [Hap] the Hap to serialize
    # @return [Hash] serializable Hash representation
    def self.serialize_hap(hap)
      {
        whole: serialize_time_span(hap.whole),
        part: serialize_time_span(hap.part),
        value: serialize_value(hap.value),
        has_onset: hap.has_onset?,
        duration: serialize_fraction(hap.duration),
      }
    end

    # Serialize a TimeSpan to a Hash
    # @param span [TimeSpan, nil] the TimeSpan to serialize
    # @return [Hash, nil] serializable representation or nil if input is nil
    def self.serialize_time_span(span)
      return nil if span.nil?

      {
        begin: serialize_fraction(span.begin_time),
        end: serialize_fraction(span.end_time),
        duration: serialize_fraction(span.duration),
      }
    end

    # Serialize a Fraction to a Hash with both rational and float representation
    # @param frac [Fraction, Rational, Numeric] the fraction to serialize
    # @return [Hash] serializable representation
    def self.serialize_fraction(frac)
      case frac
      when Fraction
        value = frac.value
      when Rational
        value = frac
      else
        value = Rational(frac)
      end

      {
        rational: "#{value.numerator}/#{value.denominator}",
        float: value.to_f,
      }
    end

    # Serialize a value (can be various types)
    # @param value the value to serialize
    # @return the value in a JSON-serializable form
    def self.serialize_value(value)
      case value
      when Hash
        # Recursively serialize hash values
        value.each_with_object({}) do |(k, v), acc|
          acc[k] = serialize_value(v)
        end
      when Array
        # Recursively serialize array elements
        value.map { |v| serialize_value(v) }
      when Fraction
        serialize_fraction(value)
      when Rational
        {
          rational: "#{value.numerator}/#{value.denominator}",
          float: value.to_f,
        }
      when Symbol
        value.to_s
      when String, Numeric, TrueClass, FalseClass, NilClass
        value
      else
        # For other types, try to convert to string
        value.to_s
      end
    end
  end
end
