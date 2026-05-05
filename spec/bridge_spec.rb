# frozen_string_literal: true

require_relative "spec_helper"
require "json"

describe Strudel::Bridge do
  describe ".evaluate" do
    it "returns a JSON string" do
      pattern = Strudel::Pattern.pure("bd")
      result = Strudel::Bridge.evaluate(pattern, 0, 1)

      assert_instance_of String, result
      # Verify it's valid JSON
      json = JSON.parse(result)
      assert_instance_of Array, json
    end

    it "serializes a simple pattern over a time range" do
      pattern = Strudel::Pattern.pure("bd")
      result = Strudel::Bridge.evaluate(pattern, 0, 1)
      haps = JSON.parse(result)

      assert_equal 1, haps.length
      hap = haps.first

      # Check structure
      assert_kind_of Hash, hap
      assert hap.key?("whole")
      assert hap.key?("part")
      assert hap.key?("value")
      assert hap.key?("has_onset")
      assert hap.key?("duration")
    end

    it "serializes Hap with correct whole and part spans" do
      pattern = Strudel::Pattern.pure("bd")
      result = Strudel::Bridge.evaluate(pattern, 0, 1)
      haps = JSON.parse(result)
      hap = haps.first

      # whole and part should be present and have begin/end/duration
      assert_kind_of Hash, hap["whole"]
      assert hap["whole"].key?("begin")
      assert hap["whole"].key?("end")
      assert hap["whole"].key?("duration")

      assert_kind_of Hash, hap["part"]
      assert hap["part"].key?("begin")
      assert hap["part"].key?("end")
      assert hap["part"].key?("duration")
    end

    it "serializes Fraction values as both rational and float" do
      pattern = Strudel::Pattern.pure("bd")
      result = Strudel::Bridge.evaluate(pattern, 0, 1)
      haps = JSON.parse(result)
      hap = haps.first

      # Check that duration is serialized as both rational and float
      assert hap["duration"].key?("rational")
      assert hap["duration"].key?("float")
      assert_equal "1/1", hap["duration"]["rational"]
      assert_kind_of Numeric, hap["duration"]["float"]
    end

    it "sets has_onset correctly" do
      pattern = Strudel::Pattern.pure("bd")
      result = Strudel::Bridge.evaluate(pattern, 0, 1)
      haps = JSON.parse(result)
      hap = haps.first

      # First hap should have onset
      assert hap["has_onset"]
    end

    it "handles Fraction inputs" do
      pattern = Strudel::Pattern.pure("bd")
      begin_frac = Strudel::Fraction.new(0)
      end_frac = Strudel::Fraction.new(1)
      result = Strudel::Bridge.evaluate(pattern, begin_frac, end_frac)
      haps = JSON.parse(result)

      assert_equal 1, haps.length
    end

    it "handles cycle offset" do
      pattern = Strudel::Pattern.pure("bd")
      result = Strudel::Bridge.evaluate(pattern, 0, 1, 0.5)
      haps = JSON.parse(result)

      assert_equal 1, haps.length
    end

    it "serializes numeric pattern values" do
      pattern = Strudel::Pattern.pure(42)
      result = Strudel::Bridge.evaluate(pattern, 0, 1)
      haps = JSON.parse(result)

      assert_equal 42, haps.first["value"]
    end

    it "serializes string pattern values" do
      pattern = Strudel::Pattern.pure("test_sound")
      result = Strudel::Bridge.evaluate(pattern, 0, 1)
      haps = JSON.parse(result)

      assert_equal "test_sound", haps.first["value"]
    end

    it "serializes hash pattern values" do
      pattern = Strudel::Pattern.pure({ note: 60, gain: 0.8 })
      result = Strudel::Bridge.evaluate(pattern, 0, 1)
      haps = JSON.parse(result)
      value = haps.first["value"]

      assert_kind_of Hash, value
      assert_equal 60, value["note"]
      assert_equal 0.8, value["gain"]
    end

    it "serializes array pattern values" do
      pattern = Strudel::Pattern.pure([1, 2, 3])
      result = Strudel::Bridge.evaluate(pattern, 0, 1)
      haps = JSON.parse(result)
      value = haps.first["value"]

      assert_kind_of Array, value
      assert_equal [1, 2, 3], value
    end

    it "handles multiple events in a pattern" do
      pattern = Strudel::Pattern.new { |state|
        [
          Strudel::Hap.new(
            Strudel::TimeSpan.new(0, 0.5),
            Strudel::TimeSpan.new(0, 0.5),
            "bd"
          ),
          Strudel::Hap.new(
            Strudel::TimeSpan.new(0.5, 1),
            Strudel::TimeSpan.new(0.5, 1),
            "hh"
          ),
        ]
      }
      result = Strudel::Bridge.evaluate(pattern, 0, 1)
      haps = JSON.parse(result)

      assert_equal 2, haps.length
      assert_equal "bd", haps[0]["value"]
      assert_equal "hh", haps[1]["value"]
    end

    it "handles nil whole span" do
      # Create a Hap with nil whole (for events without logical time)
      hap = Strudel::Hap.new(
        nil,
        Strudel::TimeSpan.new(0, 1),
        "test"
      )
      pattern = Strudel::Pattern.new { |_state| [hap] }
      result = Strudel::Bridge.evaluate(pattern, 0, 1)
      haps = JSON.parse(result)

      assert_nil haps.first["whole"]
      assert_kind_of Hash, haps.first["part"]
    end
  end
end
