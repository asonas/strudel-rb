# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/strudel/live/dollar_colon_preprocessor"

describe Strudel::Live::DollarColonPreprocessor do
  def call(input)
    Strudel::Live::DollarColonPreprocessor.call(input)
  end

  describe ".call" do
    it "rewrites unnamed single-line `$:` to track block" do
      assert_equal 'track { sound("bd") }', call('$: sound("bd")')
    end

    it "rewrites mute single-line `_$:` to _track block" do
      assert_equal '_track { sound("hh") }', call('_$: sound("hh")')
    end

    it "rewrites named single-line `$:name` to track(:name) block" do
      assert_equal 'track(:chr) { sound("bd") }', call('$:chr sound("bd")')
    end

    it "rewrites mute + named `_$:name`" do
      assert_equal '_track(:lead) { sound("hh") }', call('_$:lead sound("hh")')
    end

    it "wraps multi-line method-chain continuation in a single track block" do
      input  = "$: sound(\"bd\")\n  .gain(0.5)\n  .lpf(2000)"
      output = "track { sound(\"bd\")\n  .gain(0.5)\n  .lpf(2000) }"

      assert_equal output, call(input)
    end

    it "rewrites `$: do ... end` to `track do ... end`" do
      input  = "$: do\n  sound(\"bd\")\nend"
      output = "track do\n  sound(\"bd\")\nend"

      assert_equal output, call(input)
    end

    it "rewrites named `$:name do ... end` to `track(:name) do ... end`" do
      input  = "$:lead do\n  sound(\"hh\")\nend"
      output = "track(:lead) do\n  sound(\"hh\")\nend"

      assert_equal output, call(input)
    end

    it "rewrites mute + do/end `_$:name do ... end`" do
      input  = "_$:bass do\n  sound(\"bd\").gain(0.7)\nend"
      output = "_track(:bass) do\n  sound(\"bd\").gain(0.7)\nend"

      assert_equal output, call(input)
    end

    it "splits a trailing comment so the closing `}` does not get commented out" do
      assert_equal 'track { sound("bd") } # main', call('$: sound("bd") # main')
    end

    it "splits a trailing comment only on the last continuation line" do
      input  = "$: sound(\"bd\")\n  .gain(0.5) # main"
      output = "track { sound(\"bd\")\n  .gain(0.5) } # main"

      assert_equal output, call(input)
    end

    it "does not treat a `#` inside a double-quoted string as a comment" do
      assert_equal 'track { sound("bd # rest") }', call('$: sound("bd # rest")')
    end

    it "passes through `$LOAD_PATH` operations unchanged" do
      [
        '$:.length',
        '$: << "path"',
        '$:[0]',
      ].each do |input|
        assert_equal input, call(input)
      end
    end

    it "passes through commented-out `$:` lines" do
      assert_equal '# $: sound("bd")', call('# $: sound("bd")')
    end

    it "passes through existing `track { ... }` lines" do
      assert_equal 'track { sound("bd") }', call('track { sound("bd") }')
    end

    it "preserves indentation" do
      assert_equal '  track { sound("bd") }', call('  $: sound("bd")')
    end

    it "warns and falls back to unnamed when the track name is not a valid Ruby identifier" do
      # Ruby::Box + Minitest::capture_io do not cooperate cleanly: under
      # RUBY_BOX=1 Ruby's warn writes through a path that bypasses the
      # $stderr swap. The fallback behavior itself is identical in both
      # modes, so we only assert the warning text outside the box.
      skip "capture_io does not capture warn under Ruby::Box" if ENV["RUBY_BOX"] == "1"

      out, err = capture_io do
        result = call('$:1foo sound("bd")')
        assert_equal 'track { sound("bd") }', result
      end

      _ = out
      assert_match(/\[DollarColonPreprocessor\] line 1: invalid track name '1foo' ignored/, err)
    end

    it "leaves `_ $:` (space between mute prefix and `$:`) untouched" do
      assert_equal '_ $: sound("hh")', call('_ $: sound("hh")')
    end

    it "returns empty string for empty input" do
      assert_equal "", call("")
    end

    it "returns input unchanged when no `$:` lines are present" do
      input = "setcpm 120\nsound(\"bd\")"

      assert_equal input, call(input)
    end

    it "preserves the absence of a trailing newline" do
      input  = '$: sound("bd")'
      output = 'track { sound("bd") }'

      assert_equal output, call(input)
      refute output.end_with?("\n")
    end

    it "rewrites a mix of plain code, named, and muted `$:` tracks" do
      input  = "setcpm 120\n\n$: sound(\"bd\")\n\n_$:hh sound(\"hh*4\")\n"
      output = "setcpm 120\n\ntrack { sound(\"bd\") }\n\n_track(:hh) { sound(\"hh*4\") }\n"

      assert_equal output, call(input)
    end
  end
end
