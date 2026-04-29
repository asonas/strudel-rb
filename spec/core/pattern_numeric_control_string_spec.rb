# frozen_string_literal: true

require_relative "../spec_helper"

describe "numeric control methods with Mini-Notation string arguments" do
  describe "#speed" do
    it "parses a string as Mini-Notation and coerces values to Float" do
      pattern = Strudel::Pattern.pure({ s: "sd" }).speed("1 1 1.2 0.9")
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
      values = haps.map { |h| h.value[:speed] }
      assert_equal [1.0, 1.0, 1.2, 0.9], values
      values.each { |v| assert_kind_of Float, v }
    end

    it "still accepts numeric values" do
      pattern = Strudel::Pattern.pure({ s: "sd" }).speed(0.5)
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal 0.5, haps.first.value[:speed]
    end
  end

  describe "#gain" do
    it "parses a string as Mini-Notation and coerces values to Float" do
      pattern = Strudel::Pattern.pure({ s: "sd" }).gain("0.7 0.3")
      haps = pattern.query_arc(0, 1)

      values = haps.map { |h| h.value[:gain] }
      assert_equal [0.7, 0.3], values
      values.each { |v| assert_kind_of Float, v }
    end
  end

  describe "#pan" do
    it "parses a string as Mini-Notation and coerces values to Float" do
      pattern = Strudel::Pattern.pure({ s: "sd" }).pan("0 1 0.2 0.8")
      haps = pattern.query_arc(0, 1)

      values = haps.map { |h| h.value[:pan] }
      assert_equal [0.0, 1.0, 0.2, 0.8], values
    end
  end
end
