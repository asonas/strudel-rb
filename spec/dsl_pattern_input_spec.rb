# frozen_string_literal: true

require_relative "spec_helper"

describe "DSL functions accepting Pattern arguments" do
  let(:runner) { Strudel::Runner.new }

  describe "#n" do
    it "accepts a Pattern of strings and coerces values to integers" do
      string_pat = Strudel::Pattern.reify("0 2 4")
      result = runner.n(string_pat)

      values = result.query_arc(0, 1).map(&:value)
      assert_equal [0, 2, 4], values
    end

    it "still accepts a string (current behavior)" do
      result = runner.n("0 2 4")
      values = result.query_arc(0, 1).map(&:value)
      assert_equal [0, 2, 4], values
    end
  end

  describe "#note" do
    it "accepts a Pattern argument" do
      pat = Strudel::Pattern.reify("c4 e4")
      result = runner.note(pat)

      values = result.query_arc(0, 1).map(&:value)
      assert_equal 2, values.length
      values.each { |v| assert_kind_of Hash, v }
    end
  end

  describe "#sound" do
    it "accepts a Pattern argument" do
      pat = Strudel::Pattern.reify("bd hh")
      result = runner.sound(pat)

      values = result.query_arc(0, 1).map(&:value)
      sample_names = values.map { |v| v[:s] }
      assert_equal %w[bd hh], sample_names
    end
  end

  describe "arithmetic-then-DSL chain" do
    it "supports n(string_pat.add(string_pat))" do
      left = Strudel::Pattern.reify("0 2 4")
      right = Strudel::Pattern.reify("0 3 4")
      result = runner.n(left.add(right))

      values = result.query_arc(0, 1).map(&:value)
      assert_equal [0, 5, 8], values
    end
  end
end
