#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage:
#   1. bundle exec ruby demo/first_sounds.rb

require_relative "../lib/strudel"
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

pattern = runner.sound("bd hh sd hh")

puts "Playing: sound(\"bd hh sd hh\")"
puts ""
puts "1 cycle = 2 seconds (cps = 0.5)"
puts ""

runner.play(pattern)

loop do
  sleep 1
end
