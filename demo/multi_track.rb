#!/usr/bin/env ruby
# frozen_string_literal: true

# strudel-rb Demo: Multi-track (Arpeggio + Drums)
#
# Demonstrates playing multiple tracks simultaneously:
# - Track 1: Arpeggio melody using synthesizer
# - Track 2: Drum beat using samples
#
# Usage:
#   bundle exec ruby demo/multi_track.rb

require_relative "../lib/strudel"
include Strudel::DSL

# Signal handler (Ctrl+C to stop)
runner = nil
trap("INT") do
  puts "\nStopping..."
  runner&.cleanup
  exit
end

puts "strudel-rb Demo: Multi-track (Arpeggio + Drums)"
puts "================================================"
puts ""
puts "Press Ctrl+C to stop"
puts ""

# Track 1: Arpeggio
# C major arpeggio: C E G B (scale degrees 0 2 4 6)
arpeggio = n("<0 2 4 6>*4")
  .scale("c:major")
  .s("sine")
  .gain(0.5)

puts "Track 1 (Arpeggio): n(\"<0 2 4 6>*4\").scale(\"c:major\").s(\"sine\")"

# Track 2: Drum beat
# Basic rock beat: kick on 1 and 3, snare on 2 and 4, hi-hat on every eighth
drums = sound("bd hh sd hh")
  .gain(0.8)

puts "Track 2 (Drums): sound(\"bd hh sd hh\")"
puts ""

# Stack both tracks for parallel playback
combined = stack(arpeggio, drums)

# Create runner and play
runner = Strudel::Runner.new(cps: 0.5)
runner.play(combined)

puts "Playing..."
puts "1 cycle = 2 seconds (cps = 0.5)"
puts ""

# Keep the main thread alive
loop do
  sleep 1
end
