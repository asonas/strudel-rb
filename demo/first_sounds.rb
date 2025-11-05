#!/usr/bin/env ruby
# frozen_string_literal: true

# strudel-rb Demo: First Sounds
# Based on https://strudel.cc/workshop/first-sounds/
#
# Usage:
#   1. Place WAV files in the samples/ directory
#      samples/bd/0.wav  (bass drum)
#      samples/sd/0.wav  (snare drum)
#      samples/hh/0.wav  (hi-hat)
#   2. bundle exec ruby demo/first_sounds.rb

require_relative "../lib/strudel"

# Create a Runner
runner = Strudel::Runner.new(cps: 0.5)

# Signal handler (Ctrl+C to stop)
trap("INT") do
  puts "\nStopping..."
  runner.cleanup
  exit
end

puts "strudel-rb Demo: First Sounds"
puts "=============================="
puts ""
puts "Press Ctrl+C to stop"
puts ""

# Create and play a pattern
# Basic drum pattern: bd hh sd hh
pattern = runner.sound("bd hh sd hh")

puts "Playing: sound(\"bd hh sd hh\")"
puts ""
puts "1 cycle = 2 seconds (cps = 0.5)"
puts ""

runner.play(pattern)

# Keep the main thread alive
loop do
  sleep 1
end
