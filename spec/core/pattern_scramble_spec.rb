# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Pattern do
  describe "#scramble" do
    it "returns the same number of haps as chop(n)" do
      pat = Strudel::Pattern.pure(s: "x").scramble(4)
      haps = pat.query_arc(0, 1)
      assert_equal 4, haps.length
    end

    it "is deterministic — same cycle produces the same order on repeat queries" do
      pat = Strudel::Pattern.pure(s: "x").scramble(8)
      first = pat.query_arc(0, 1).map { |h| h.value[:begin] }
      second = pat.query_arc(0, 1).map { |h| h.value[:begin] }
      assert_equal first, second
    end

    it "keeps time slots identical to chop(n) — only values are shuffled" do
      chopped = Strudel::Pattern.pure(s: "x").chop(4)
      scrambled = Strudel::Pattern.pure(s: "x").scramble(4)

      chopped_times = chopped.query_arc(0, 1).map { |h| [h.part.begin_time, h.part.end_time] }
      scrambled_times = scrambled.query_arc(0, 1).map { |h| [h.part.begin_time, h.part.end_time] }

      assert_equal chopped_times, scrambled_times
    end

    it "shuffles — the order is not monotonically increasing" do
      pat = Strudel::Pattern.pure(s: "x").scramble(8)
      begins = pat.query_arc(0, 1).map { |h| h.value[:begin] }
      refute_equal begins.sort, begins
    end

    it "produces different orders across cycles (at least one difference in 8 cycles)" do
      pat = Strudel::Pattern.pure(s: "x").scramble(4)
      orders = (0...8).map { |c| pat.query_arc(c, c + 1).map { |h| h.value[:begin] } }
      refute_equal 1, orders.uniq.length
    end
  end
end
