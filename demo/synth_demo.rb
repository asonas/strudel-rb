#!/usr/bin/env ruby
# frozen_string_literal: true

# strudel-rb Demo: Synth Waveforms
# Demonstrates different waveforms: sine, sawtooth, square, triangle, supersaw
#
# Usage:
#   bundle exec ruby demo/synth_demo.rb

require_relative "../lib/strudel"
include Strudel::DSL

# Signal handler (Ctrl+C to stop)
runner = nil
trap("INT") do
  puts "\nStopping..."
  runner&.cleanup
  exit
end

puts "strudel-rb Demo: Synth Waveforms"
puts "================================="
puts ""
puts "Press Ctrl+C to stop"
puts ""

# Simple melody using different waveforms each cycle
# Using slowcat to cycle through waveforms
pattern = n("<0 2 4 7>")
  .scale("c:major")
  .s("<sine sawtooth square triangle supersaw>")
  .gain(0.7)

puts "Pattern: n(\"<0 2 4 7>\").scale(\"c:major\").s(\"<sine sawtooth square triangle supersaw>\")"
puts ""
puts "Waveform order: sine -> sawtooth -> square -> triangle -> supersaw"
puts ""

runner = Strudel::Runner.new(cps: 0.5)
runner.play(pattern)

puts "Playing..."
puts "1 cycle = 2 seconds (cps = 0.5)"
puts ""

loop do
  sleep 1
end

