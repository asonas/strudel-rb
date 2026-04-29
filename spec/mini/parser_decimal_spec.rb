# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Mini::Parser do
  def parse(input)
    Strudel::Mini::Parser.new.parse(input)
  end

  describe "decimal atoms" do
    it "parses a single decimal atom" do
      pattern = parse("1.2")
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal "1.2", haps.first.value
    end

    it "parses a sequence mixing integers and decimals" do
      pattern = parse("1 1 1.2 0.9")
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
      assert_equal %w[1 1 1.2 0.9], haps.map(&:value)
    end
  end
end
