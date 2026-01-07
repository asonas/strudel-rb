#!/usr/bin/env ruby
# frozen_string_literal: true

# strudel-rb Demo: register
#
# `register` defines a new method on Strudel::Pattern.
# This makes it easy to package your own "effect chain" as a single method.
#
# Usage:
#   bundle exec ruby demo/register_demo.rb

require_relative "../lib/strudel"
include Strudel::DSL

runner = nil
trap("INT") do
  puts "\nStopping..."
  runner&.cleanup
  exit
end

puts "strudel-rb Demo: register"
puts "========================"
puts ""

puts "This demo defines 2 custom Pattern methods with `register` and uses them in a chain."
puts "1 cycle = 2 seconds (cps = 0.5)"
puts ""

# Transpose by octaves.
# Example: pat.oct(-1) == pat.trans(-12)
register(:oct) do |octaves, pat|
  pat.trans(12 * octaves.to_i)
end

# Acid-style filter envelope helper (x: 0.0..1.0).
register(:acidenv) do |x, pat|
  x = x.to_f
  cutoff = 200 + x * 2000
  pat.lpf(cutoff).lpq(12).lpenv(x * 6).lps(0.2).lpd(0.15)
end

puts "Registered:"
puts "  - oct(octaves): transpose by octaves"
puts "  - acidenv(x):   filter envelope helper (x: 0.0..1.0)"
puts ""

runner = Strudel::Runner.new(cps: 0.5)

pattern =
  n("<0 4 7 9>*4")
    .scale("g:minor")
    .oct(-1)
    .s("sawtooth")
    .acidenv(0.6)
    .gain(0.4)

puts "Playing:"
puts "  n(\"<0 4 7 9>*4\").scale(\"g:minor\").oct(-1).s(\"sawtooth\").acidenv(0.6)"
puts ""
puts "Press Ctrl+C to stop"
puts ""

runner.play(pattern)
loop { sleep 1 }
