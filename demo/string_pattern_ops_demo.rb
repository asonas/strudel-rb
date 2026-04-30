#!/usr/bin/env ruby
# frozen_string_literal: true

# strudel-rb Demo: Strudel-style String operators via Ruby::Box
#
# Usage:
#   RUBY_BOX=1 bundle exec ruby demo/string_pattern_ops_demo.rb
#
# This demo evaluates a snippet that uses `"0 2 4".add("<0 3 4 0>")` style
# arithmetic on bare mini-notation strings. The required String monkey patch
# is applied inside a Ruby::Box per evaluation, so it does not leak out.

require_relative "../lib/strudel"

unless defined?(Ruby::Box) && Ruby::Box.respond_to?(:enabled?) && Ruby::Box.enabled?
  warn "This demo needs Ruby 4.0+ with RUBY_BOX=1."
  warn "Re-run with:  RUBY_BOX=1 bundle exec ruby #{$PROGRAM_NAME}"
  exit 1
end

evaluator = Strudel::Live::PatternEvaluator.new

snippet = <<~RUBY
  track(:arp) {
    n("0 2 4".add("<0 3 4 0>"))
      .scale("c:major")
      .s("sawtooth")
      .gain(0.4)
      .lpf(1500)
  }
  track(:drums) { sound("bd*4").gain(0.5) }
RUBY

pattern = evaluator.evaluate_string(snippet)

puts "Box-evaluated pattern: #{pattern.class}"
puts "Sample of haps in [0, 1):"
pattern.query_arc(0, 1).first(8).each do |hap|
  puts "  #{hap.part.begin_time.to_f.round(3)}..#{hap.part.end_time.to_f.round(3)} -> #{hap.value.inspect}"
end

# Confirm the patch did not leak.
begin
  "0 2 4".add("<0 3 4 0>")
  puts "[BUG] String#add reachable outside the Box!"
rescue NoMethodError => e
  puts "OK: outside the Box, String#add is undefined (#{e.message[0, 60]}...)"
end
