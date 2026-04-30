# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/strudel/live/pattern_evaluator"

describe "Strudel::Live::PatternEvaluator with Ruby::Box" do
  before do
    skip "RUBY_BOX not enabled" unless ENV["RUBY_BOX"] == "1"
    skip "Ruby::Box not available" unless defined?(Ruby::Box) && Ruby::Box.respond_to?(:enabled?) && Ruby::Box.enabled?
  end

  def evaluator
    @evaluator ||= Strudel::Live::PatternEvaluator.new
  end

  it "evaluates Strudel-style String#add chains and returns a Pattern" do
    code = 'n("0 2 4".add("0 3 4"))'
    result = evaluator.evaluate_string(code)

    assert_kind_of Strudel::Pattern, result
    values = result.query_arc(0, 1).map(&:value)
    assert_equal [0, 5, 8], values
  end

  it "supports the canonical Strudel example: n(...).scale(...)" do
    code = 'n("0 2 4".add("<0 3 4 0>")).scale("c:major")'
    result = evaluator.evaluate_string(code)

    assert_kind_of Strudel::Pattern, result
    haps = result.query_arc(0, 1)
    refute_empty haps
  end

  it "does not leak String#add outside the Box after evaluation" do
    evaluator.evaluate_string('n("0 2 4".add("0 3 4"))')

    assert_raises(NoMethodError) { "0".add("1") }
  end

  it "still supports the existing track DSL" do
    code = <<~RUBY
      track(:k) { sound("bd*4").gain(0.5) }
    RUBY

    result = evaluator.evaluate_string(code)
    assert_kind_of Strudel::Pattern, result
    refute_empty result.query_arc(0, 1)
  end

  it "produces a Pattern whose class identity matches the host Strudel::Pattern" do
    result = evaluator.evaluate_string('n("0 2 4".add("0 3 4"))')

    assert_equal Strudel::Pattern.object_id, result.class.object_id
  end
end
