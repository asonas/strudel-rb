# frozen_string_literal: true

require_relative "spec_helper"

describe "cutup and stutter register macros" do
  describe "cutup" do
    it "produces n sub-haps per cycle (equivalent to scramble(n) alone)" do
      pat = Strudel::Pattern.pure(s: "x").cutup(4)
      haps = pat.query_arc(0, 1)
      assert_equal 4, haps.length
    end

    it "is equivalent to scramble(n)" do
      cutup_pat = Strudel::Pattern.pure(s: "x").cutup(4)
      scramble_pat = Strudel::Pattern.pure(s: "x").scramble(4)

      cutup_haps = cutup_pat.query_arc(0, 1).map { |h| [h.part.begin_time, h.value[:begin]] }
      scramble_haps = scramble_pat.query_arc(0, 1).map { |h| [h.part.begin_time, h.value[:begin]] }

      assert_equal scramble_haps, cutup_haps
    end

    it "accepts a Pattern for n" do
      n_pat = Strudel::Mini::Parser.new.parse("<4 2>").with_value { |v| v.to_i }
      pat = Strudel::Pattern.pure(s: "x").cutup(n_pat)

      assert_equal 4, pat.query_arc(0, 1).length
      assert_equal 2, pat.query_arc(1, 2).length
    end
  end

  describe "stutter" do
    it "produces n*n sub-haps per cycle (chop then scramble over-subdivides)" do
      pat = Strudel::Pattern.pure(s: "x").stutter(4)
      haps = pat.query_arc(0, 1)
      assert_equal 16, haps.length
    end

    it "is equivalent to chop(n).scramble(n)" do
      stutter_pat = Strudel::Pattern.pure(s: "x").stutter(4)
      combo_pat = Strudel::Pattern.pure(s: "x").chop(4).scramble(4)

      stutter_haps = stutter_pat.query_arc(0, 1).map { |h| [h.part.begin_time, h.value[:begin]] }
      combo_haps = combo_pat.query_arc(0, 1).map { |h| [h.part.begin_time, h.value[:begin]] }

      assert_equal combo_haps, stutter_haps
    end
  end
end
