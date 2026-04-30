# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/strudel/live/string_pattern_ops"

# Globally prepending StringPatternOps to String would clobber the builtin
# String#sub for the rest of the suite. To exercise the module without that
# pollution we extend per-instance via Object#extend so only the local string
# objects get the patch.
describe Strudel::Live::StringPatternOps do
  def patched(str)
    str.dup.extend(Strudel::Live::StringPatternOps)
  end

  it "exposes .add returning a numeric Pattern" do
    pat = patched("0 2 4").add("0 3 4")
    assert_kind_of Strudel::Pattern, pat

    values = pat.query_arc(0, 1).map(&:value)
    assert_equal [0.0, 5.0, 8.0], values
  end

  it "exposes .mul" do
    pat = patched("1 2 3").mul("2")
    values = pat.query_arc(0, 1).map(&:value)
    assert_equal [2.0, 4.0, 6.0], values
  end

  it "exposes .sub" do
    pat = patched("5 5 5").sub("1 2 3")
    values = pat.query_arc(0, 1).map(&:value)
    assert_equal [4.0, 3.0, 2.0], values
  end

  it "exposes .div and .pow" do
    div_pat = patched("10 8").div("2")
    assert_equal [5.0, 4.0], div_pat.query_arc(0, 1).map(&:value)

    pow_pat = patched("2 3").pow("2")
    assert_equal [4.0, 9.0], pow_pat.query_arc(0, 1).map(&:value)
  end

  it "does not affect String instances that were not extended" do
    plain = "5 5 5"
    assert_equal "1 5 5", plain.sub("5", "1")
  end
end
