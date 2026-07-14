# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/strudel/live/pattern_evaluator"

describe "Strudel::Live::PatternEvaluator with $: notation" do
  def evaluator
    @evaluator ||= Strudel::Live::PatternEvaluator.new
  end

  it "registers a track via `$:` and returns the stacked tracks pattern" do
    result = evaluator.evaluate_string('$: sound("bd")')

    assert_instance_of Strudel::Pattern, result
    values = result.query_arc(0, 1).map { |h| h.value[:s] }
    assert_includes values, "bd"
  end

  it "excludes `_$:` muted tracks from the result" do
    result = evaluator.evaluate_string(<<~RUBY)
      $: sound("bd")
      _$: sound("hh")
    RUBY

    values = result.query_arc(0, 1).map { |h| h.value[:s] }
    assert_includes values, "bd"
    refute_includes values, "hh"
  end

  it "registers a named track under its symbol key" do
    evaluator.evaluate_string('$:chr sound("bd")')
    registry = evaluator.instance_variable_get(:@track_registry)

    assert registry.key?(:chr), "expected :chr to be registered, got #{registry.keys.inspect}"
  end

  it "clears the track registry between evaluations" do
    result1 = evaluator.evaluate_string('$: sound("bd")')
    values1 = result1.query_arc(0, 1).map { |h| h.value[:s] }
    assert_equal ["bd"], values1

    result2 = evaluator.evaluate_string('$: sound("hh")')
    values2 = result2.query_arc(0, 1).map { |h| h.value[:s] }
    assert_equal ["hh"], values2
  end

  it "still supports legacy `track { ... }` calls without regression" do
    result = evaluator.evaluate_string('track { sound("bd") }')

    values = result.query_arc(0, 1).map { |h| h.value[:s] }
    assert_includes values, "bd"
  end

  it "supports a mix of `$:` and explicit `track { ... }` in the same file" do
    result = evaluator.evaluate_string(<<~RUBY)
      $: sound("bd")
      track { sound("hh") }
    RUBY

    values = result.query_arc(0, 1).map { |h| h.value[:s] }
    assert_includes values, "bd"
    assert_includes values, "hh"
  end
end

describe "Strudel::Live::PatternEvaluator with $: notation under Ruby::Box" do
  before do
    skip "RUBY_BOX not enabled" unless ENV["RUBY_BOX"] == "1"
    skip "Ruby::Box not available" unless defined?(Ruby::Box) && Ruby::Box.respond_to?(:enabled?) && Ruby::Box.enabled?
  end

  def evaluator
    @evaluator ||= Strudel::Live::PatternEvaluator.new
  end

  it "preprocesses `$:` and runs StringPatternOps chains inside the Box" do
    code = '$: n("0 2 4".add("0 3 4"))'
    result = evaluator.evaluate_string(code)

    assert_instance_of Strudel::Pattern, result
    refute_empty result.query_arc(0, 1)
  end
end
