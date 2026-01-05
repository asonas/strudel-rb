#!/usr/bin/env ruby
# frozen_string_literal: true

# strudel-rb Demo: Custom Functions with register
#
# This demo replicates the following Strudel code:
#
#   register('o', (orbit, pat) => pat.orbit(orbit));
#   register('rlpf', (x, pat) => { return pat.lpf(pure(x).mul(12).pow(4)) })
#   register('acidenv', (x, pat) => pat.rlpf(.25).lpenv(x * 9).lps(.2).lpd(.15))
#
#   $: n("<0 4 0 9 7>*16".add("<7 - - 6 5 - - 6>*7")).scale("9:minor").trans(-12)
#      .o(3).s("sawtooth").acidenv(slider(0.602))
#
#   $: n("<0>*16").scale("9:minor").trans(-24)
#      .detune(rand).o(4).s("supersaw").acidenv(slider(0.8))
#
# Usage:
#   bundle exec ruby demo/register_demo.rb

require_relative "../lib/strudel"
include Strudel::DSL

# Signal handler (Ctrl+C to stop)
runner = nil
trap("INT") do
  puts "\nStopping..."
  runner&.cleanup
  exit
end

puts "strudel-rb Demo: Custom Functions with register"
puts "================================================"
puts ""

# ============================================================
# Register custom functions (mimicking Strudel's register)
# ============================================================

# rlpf: Resonant low-pass filter
# Original: pat.lpf(pure(x).mul(12).pow(4))
# This calculates: (x * 12) ^ 4 as the cutoff frequency
register(:rlpf) do |x, pat|
  cutoff = (x * 12)**4
  pat.lpf(cutoff)
end

# acidenv: Acid envelope
# Original: pat.rlpf(.25).lpenv(x * 9).lps(.2).lpd(.15)
# Now using actual lpenv, lps, lpd methods
register(:acidenv) do |x, pat|
  pat.rlpf(0.25)
    .lpenv(x * 9 * 1000)  # Envelope amount in Hz
    .lps(0.2)              # Sustain level
    .lpd(0.15)             # Decay time
    .lpq(0.6)              # Resonance
end

puts "Registered custom functions: :rlpf, :acidenv"
puts ""
puts "Built-in methods now available:"
puts "  - orbit(n) / o(n): Audio routing channel"
puts "  - lpf(hz): Low-pass filter cutoff"
puts "  - lpenv(amount): LPF envelope amount"
puts "  - lpd(seconds): LPF envelope decay"
puts "  - lps(level): LPF envelope sustain"
puts "  - lpq(resonance): LPF resonance"
puts ""

# ============================================================
# Define patterns (mimicking Strudel's $: syntax)
# ============================================================

# Track 1: Acid lead
# Original: n("<0 4 0 9 7>*16".add("<7 - - 6 5 - - 6>*7"))
#           .scale("9:minor").trans(-12).o(3).s("sawtooth").acidenv(0.602)
#
# Note: "9:minor" means root note = 9 (A) with minor scale
track1 = n("<0 4 0 9 7>*16")
  .add(n("<7 - - 6 5 - - 6>*7"))
  .scale("a:minor")    # 9:minor = A minor
  .trans(-12)          # Down one octave
  .o(3)                # Orbit 3 (for routing)
  .s("sawtooth")       # Sawtooth waveform
  .acidenv(0.602)      # Acid envelope
  .gain(0.5)           # Reduce volume

puts "Track 1: Acid lead (sawtooth)"
puts "  n(\"<0 4 0 9 7>*16\").add(n(\"<7 - - 6 5 - - 6>*7\"))"
puts "  .scale(\"a:minor\").trans(-12).o(3).s(\"sawtooth\").acidenv(0.602)"
puts ""

# Track 2: Supersaw bass
# Original: n("<0>*16").scale("9:minor").trans(-24)
#           .detune(rand).o(4).s("supersaw").acidenv(0.8)
#
# Note: Using fixed detune value (rand would vary per event)
track2 = n("<0>*16")
  .scale("a:minor")    # A minor
  .trans(-24)          # Down two octaves (bass)
  .detune(0.03)        # Fixed detune
  .o(4)                # Orbit 4
  .s("supersaw")       # Supersaw waveform
  .acidenv(0.8)        # Acid envelope
  .gain(0.4)           # Reduce volume

puts "Track 2: Supersaw bass"
puts "  n(\"<0>*16\").scale(\"a:minor\").trans(-24)"
puts "  .detune(0.03).o(4).s(\"supersaw\").acidenv(0.8)"
puts ""

# ============================================================
# Play both tracks together
# ============================================================

combined = stack(track1, track2)

runner = Strudel::Runner.new(cps: 0.5)
runner.play(combined)

puts "Playing both tracks..."
puts "1 cycle = 2 seconds (cps = 0.5)"
puts ""
puts "Press Ctrl+C to stop"
puts ""

# Keep the main thread alive
loop do
  sleep 1
end
