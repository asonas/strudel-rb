# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Pattern do
  describe "#fit" do
    it "sets unit: \"c\" on hap values" do
      pat = Strudel::Pattern.pure(s: "amen").fit
      hap = pat.query_arc(0, 1).first

      assert_equal "c", hap.value[:unit]
    end

    it "sets speed based on cps and hap whole duration" do
      original_cps = Strudel.cps
      Strudel.setcps(1.0)

      begin
        pat = Strudel::Pattern.pure(s: "amen").fit
        hap = pat.query_arc(0, 1).first
        # whole duration = 1 cycle, cps = 1, slicedur defaults to 1 -> speed = 1.0
        assert_in_delta 1.0, hap.value[:speed], 1e-9
      ensure
        Strudel.setcps(original_cps)
      end
    end

    it "scales speed inversely with hap duration" do
      original_cps = Strudel.cps
      Strudel.setcps(1.0)

      begin
        # fast(2) halves hap duration -> speed should double
        # Note: fast must be applied before fit so fit sees the compressed hap duration
        pat = Strudel::Pattern.pure(s: "amen").fast(2).fit
        hap = pat.query_arc(0, 1).first
        assert_in_delta 2.0, hap.value[:speed], 1e-9
      ensure
        Strudel.setcps(original_cps)
      end
    end

    it "wraps non-hash values into {s:, unit:, speed:}" do
      pat = Strudel::Pattern.pure("amen").fit
      hap = pat.query_arc(0, 1).first

      assert_equal "amen", hap.value[:s]
      assert_equal "c", hap.value[:unit]
      refute_nil hap.value[:speed]
    end
  end
end
