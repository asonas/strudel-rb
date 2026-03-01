# frozen_string_literal: true

require_relative "spec_helper"

describe Strudel::DSL do
  include Strudel::DSL

  # Phase 4.1
  describe "#stepcat" do
    it "concatenates patterns proportionally" do
      # 3 steps of "a", 1 step of "b" => total 4 steps in 1 cycle
      pattern = stepcat([3, pure("a")], [1, pure("b")])
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal "a", haps[0].value
      assert_equal "b", haps[1].value

      # "a" takes 3/4 of the cycle, "b" takes 1/4
      a_duration = haps[0].whole.duration
      b_duration = haps[1].whole.duration
      assert_equal Strudel::Fraction.new(Rational(3, 4)), a_duration
      assert_equal Strudel::Fraction.new(Rational(1, 4)), b_duration
    end
  end

  # Phase 4.2
  describe "#ar" do
    it "arranges sections sequentially by cycle count" do
      pattern = ar(2, pure("a"), 2, pure("b"))

      # Total is 4 cycles, slowed by 4
      # First 2 cycles: "a", next 2 cycles: "b"
      haps0 = pattern.query_arc(0, 1)
      assert_equal "a", haps0.first.value

      haps1 = pattern.query_arc(1, 2)
      assert_equal "a", haps1.first.value

      haps2 = pattern.query_arc(2, 3)
      assert_equal "b", haps2.first.value

      haps3 = pattern.query_arc(3, 4)
      assert_equal "b", haps3.first.value
    end
  end

  # Phase 4.3
  describe "#block_arrange" do
    it "passes through with F mask" do
      pat = pure("bd")
      mask_pat = pure("F")
      result = block_arrange([[pat, mask_pat]])
      haps = result.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal "bd", haps.first.value
    end

    it "silences with 0 mask" do
      pat = pure("bd")
      mask_pat = pure("0")
      result = block_arrange([[pat, mask_pat]])
      haps = result.query_arc(0, 1)

      assert_empty haps
    end

    it "reverses and sets negative speed with B mask" do
      pat = Strudel::Pattern.fastcat(
        Strudel::Pattern.pure({ s: "a" }),
        Strudel::Pattern.pure({ s: "b" }),
        Strudel::Pattern.pure({ s: "c" }),
        Strudel::Pattern.pure({ s: "d" })
      )
      mask_pat = pure("B")
      result = block_arrange([[pat, mask_pat]])
      haps = result.query_arc(0, 1)

      assert_equal 4, haps.length
      assert_equal "d", haps[0].value[:s]
      assert_equal "c", haps[1].value[:s]
      assert_equal "b", haps[2].value[:s]
      assert_equal "a", haps[3].value[:s]
      assert_equal(-1, haps[0].value[:speed])
    end

    it "stacks multiple tracks" do
      pat1 = pure("bd")
      pat2 = pure("hh")
      result = block_arrange(
        [[pat1, pure("F")], [pat2, pure("F")]]
      )
      haps = result.query_arc(0, 1)

      values = haps.map(&:value)
      assert_includes values, "bd"
      assert_includes values, "hh"
    end
  end
end
