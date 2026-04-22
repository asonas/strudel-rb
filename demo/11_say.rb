#!/usr/bin/env ruby
# frozen_string_literal: true

# strudel-rb Demo: say (Text-to-Speech)
#
# `say` converts a text pattern into spoken audio using macOS TTS (`say` command).
# Pass a Pattern of strings to cycle through words in sync with the beat.
#
# Usage:
#   bundle exec ruby demo/11_say.rb

require_relative "../lib/strudel"
include Strudel::DSL

runner = nil
trap("INT") do
  puts "\nStopping..."
  runner&.cleanup
  exit
end

puts "strudel-rb Demo: say (Text-to-Speech)"
puts "======================================"
puts ""
puts "Uses macOS `say` command to speak words in rhythm."
puts "1 cycle = 2 seconds (cps = 0.5)"
puts ""

runner = Strudel::Runner.new(cps: 0.5)

# Parse a mini-notation string into a Pattern of words,
# then wrap it with say() to convert each word to TTS audio.
words = Mini::Parser.new.parse("<ruby strudel live coding>")
speech = say(words)

# Drum pattern running in parallel
drums = sound("bd ~ sd ~")

pattern = stack(speech, drums)

puts "Pattern:"
puts "  words:  <ruby strudel live coding>  (slowcat: one word per cycle)"
puts "  drums:  sound(\"bd ~ sd ~\")"
puts ""
puts "Press Ctrl+C to stop"
puts ""

runner.play(pattern)
loop { sleep 1 }
