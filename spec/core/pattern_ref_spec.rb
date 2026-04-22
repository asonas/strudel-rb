# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Pattern do
  describe ".ref" do
    it "evaluates the accessor on every query" do
      counter = 0
      pattern = Strudel::Pattern.ref { counter += 1 }

      haps1 = pattern.query_arc(0, 1)
      haps2 = pattern.query_arc(1, 2)

      assert_equal 1, haps1.first.value
      assert_equal 2, haps2.first.value
    end

    it "reifies non-pattern values" do
      value = 42
      pattern = Strudel::Pattern.ref { value }
      haps = pattern.query_arc(0, 1)

      assert_equal 42, haps.first.value
    end

    it "returns one hap per cycle" do
      pattern = Strudel::Pattern.ref { 0.5 }
      haps = pattern.query_arc(0, 2)

      assert_equal 2, haps.length
      assert_equal 0.5, haps[0].value
      assert_equal 0.5, haps[1].value
    end
  end
end
