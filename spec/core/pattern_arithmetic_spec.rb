# frozen_string_literal: true

require_relative "../spec_helper"

describe "Pattern arithmetic with string values" do
  describe "#add" do
    it "treats mini-notation string values as numerals when adding" do
      left = Strudel::Pattern.reify("0 2 4")
      right = Strudel::Pattern.reify("0 3 4")

      result = left.add(right)
      values = result.query_arc(0, 1).map(&:value)

      assert_equal [0.0, 5.0, 8.0], values
    end

    it "still concatenates non-numeric string values" do
      left = Strudel::Pattern.reify("a b")
      right = Strudel::Pattern.reify("x y")

      result = left.add(right)
      values = result.query_arc(0, 1).map(&:value)

      assert_equal ["ax", "by"], values
    end
  end

  describe "#mul" do
    it "treats mini-notation string values as numerals when multiplying" do
      left = Strudel::Pattern.reify("1 2 3")
      right = Strudel::Pattern.reify("2")

      result = left.mul(right)
      values = result.query_arc(0, 1).map(&:value)

      assert_equal [2.0, 4.0, 6.0], values
    end
  end

  describe "Hash value arithmetic" do
    it "still merges shared numeric keys" do
      left = Strudel::Pattern.pure({ gain: 0.5 })
      right = Strudel::Pattern.pure({ gain: 0.2 })

      result = left.add(right)
      hap = result.query_arc(0, 1).first

      assert_in_delta 0.7, hap.value[:gain]
    end
  end
end
