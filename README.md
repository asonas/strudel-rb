# strudel-rb

A Strudel-like live coding music library for Ruby.

## Overview

strudel-rb is a Ruby library inspired by [Strudel](https://strudel.cc/) (the JavaScript implementation of Tidal Cycles). It allows you to write drum patterns and sequences concisely using Mini-Notation and play them in real-time.

## Installation

```bash
bundle install
```

## Sample Files Setup

Place WAV files in the `samples/` directory with the following structure:

```
samples/
├── bd/
│   └── 0.wav    # Bass drum
├── sd/
│   └── 0.wav    # Snare
├── hh/
│   └── 0.wav    # Hi-hat
├── cp/
│   └── 0.wav    # Clap
└── oh/
    └── 0.wav    # Open hi-hat
```

## Usage

### Basic Usage

```ruby
require_relative 'lib/strudel'

runner = Strudel::Runner.new(cps: 0.5)

# Play a drum pattern
pattern = runner.sound("bd hh sd hh")
runner.play(pattern)

sleep 10  # Play for 10 seconds

runner.cleanup
```

### Tempo (CPS / BPM)

strudel-rb follows Strudel/Tidal's concept of **CPS (cycles per second)** for tempo.
You can set it either when creating a `Runner`, or declaratively with `setcps` / `setcpm` at the top of your pattern file.

- `setcps(x)`: set cycles per second
- `setcpm(x)`: set cycles per minute (`setcps(x / 60)`)

If you want to think in BPM, the mapping depends on how many **perceived beats per cycle (bpc)** you use:

\[
\text{bpm} = \text{cps} \times 60 \times \text{bpc}
\]

Example (common 4/4 interpretation: `bpc = 4`):

```ruby
require_relative 'lib/strudel'
include Strudel::DSL

setcpm(120 / 4) # => 120 bpm with 4 beats per cycle (cps = 0.5)
# or:
setbpm(120, bpc: 4)

runner = Strudel::Runner.new # picks up Strudel.cps unless you pass cps:
runner.play(sound("bd sd bd sd"))
```

Reference: [`setcps` (TidalCycles)](https://tidalcycles.org/docs/reference/tempo/#setcps)

### Live Coding (Watch Mode)

You can create a pattern file and run it directly with the watch script. The file will be automatically reloaded when you save changes.

1. Create a pattern file (e.g., `pattern.rb`):

```ruby
sound("bd hh sd hh")
```

2. Run with the watch script:

```bash
bundle exec ruby bin/strudel-watch pattern.rb
```

The pattern will play immediately, and any changes you make to the file will be hot-reloaded in real-time. Press Ctrl+C to stop.

Example pattern files:

```ruby
# Simple drum pattern
sound("bd hh sd hh")

# Strudel-like $: (auto stack) with mute via _track
# - use `track { ... }` to add a track
# - use `_track { ... }` to mute a track without commenting the whole block
track(:drums) { sound("bd hh sd hh") }
_track(:hats) { sound("hh*8") }

# Using samples with fit (requires your own sample file)
# Place samples/breaks165/0.wav in your project
s("breaks165").fit

# Parallel patterns
sound("bd sd, hh*4")
```

### Synthesizers

strudel-rb includes built-in synthesizers that generate sound using oscillators. Available waveforms:

| Waveform | Description |
|----------|-------------|
| `sine` | Smooth, pure tone |
| `sawtooth` | Bright, buzzy tone |
| `square` | Hollow, harsh tone |
| `triangle` | Softer than square, similar to sine |
| `supersaw` | Multiple detuned sawtooth waves (rich, full sound) |

Example usage:

```ruby
# Play a sine wave at C4
note("c4 e4 g4").sound("sine")

# Play a sawtooth wave
note("c3 c4").sound("sawtooth")

# Play with different waveforms
note("c4").sound("square")
note("c4").sound("triangle")

# Supersaw with detune control
note("c3").sound("supersaw").detune(0.02)
```

You can also use synthesizers in pattern files:

```ruby
# In pattern.rb
note("c4 e4 g4 b4").sound("sine")
```

### Filters and Envelopes

Apply low-pass filter with envelope modulation for classic synth sounds:

```ruby
include Strudel::DSL

# Basic low-pass filter
n("0 4 7").scale("c:major").s("sawtooth").lpf(800)

# Low-pass filter with resonance
n("0 4 7").scale("c:major").s("sawtooth").lpf(800).lpq(8)

# Filter envelope (acid-style)
n("0 4 7").scale("c:major").s("sawtooth")
  .lpf(400)        # Base cutoff frequency
  .lpenv(4)        # Envelope depth (octaves)
  .lpd(0.15)       # Decay time (seconds)
  .lps(0.2)        # Sustain level (0-1)
  .lpq(8)          # Q (0-50)
```

| Method | Description |
|--------|-------------|
| `lpf(hz)` | Low-pass filter cutoff frequency |
| `lpenv(amount)` | Filter envelope depth (octaves) |
| `lpa(seconds)` | Filter envelope attack time |
| `lpd(seconds)` | Filter envelope decay time |
| `lps(level)` | Filter envelope sustain level (0-1) |
| `lpr(seconds)` | Filter envelope release time |
| `lpq(q)` | Filter resonance/Q (0-50) |
| `orbit(n)` | Audio routing channel |

### Scales and Transpose

Use `scale()` to convert scale degrees to notes, and `trans()` to transpose:

```ruby
include Strudel::DSL

# Scale degrees 0, 2, 4 in C major -> C4, E4, G4
n("0 2 4").scale("c:major").s("sine")

# A minor scale (root = A)
n("<0 2 4 7>").scale("a:minor").s("sawtooth")

# Transpose down one octave (-12 semitones)
n("0 4 7").scale("c:major").trans(-12).s("sine")
```

Available scales: `major`, `minor`, `dorian`, `phrygian`, `lydian`, `mixolydian`, `locrian`, `chromatic`, `pentatonic`, `blues`, `wholetone`

### Multi-track Playback

Use `stack()` to play multiple patterns in parallel:

```ruby
include Strudel::DSL

# Define two tracks
track1 = n("<0 4 7>").scale("c:major").s("sawtooth").gain(0.6)
track2 = n("<0>*4").scale("c:major").trans(-12).s("sine").gain(0.4)

# Play both tracks together
runner = Runner.new(cps: 0.5)
runner.play(stack(track1, track2))
```

### Custom Functions (register)

Define your own pattern transformations using `register`:

```ruby
include Strudel::DSL

# Register a custom effect
register(:my_bass) do |x, pat|
  pat.trans(-24).gain(x)
end

# Use it in a pattern chain
n("0 4 7").scale("c:minor").s("supersaw").my_bass(0.8)
```

More complex example (acid-style effects):

```ruby
# Resonant low-pass filter: cutoff = (x * 12)^4
register(:rlpf) do |x, pat|
  cutoff = (x * 12)**4
  pat.lpf(cutoff)
end

# Acid envelope (simplified)
register(:acidenv) do |x, pat|
  cutoff = 200 + x * 2000
  pat.lpf(cutoff)
end

# Use in pattern
n("<0 4 7>*8").scale("a:minor").s("sawtooth").acidenv(0.6)
```

### Random Patterns

Use `rand` for random values between 0.0 and 1.0:

```ruby
include Strudel::DSL

# Random detune
n("0").scale("c:major").s("supersaw").detune(rand.mul(0.05))

# Random note selection (0-7)
irand(8).scale("c:pentatonic").s("sine")

# Random gain variation
n("0 4 7").scale("c:major").s("sawtooth").gain(rand.mul(0.5).add(0.5))
```

### Mini-Notation

| Syntax | Description | Example |
|--------|-------------|---------|
| `space` | Sequence | `"bd hh sd hh"` |
| `:n` | Sample number | `"hh:0 hh:1 hh:2"` |
| `-` or `~` | Rest | `"bd - sd -"` |
| `[...]` | Sub-sequence | `"bd [hh hh] sd"` |
| `*n` | n times faster | `"bd*2"` |
| `,` | Parallel playback | `"bd sd, hh hh hh hh"` |
| `<...>` | One per cycle | `"<bd sd hh>"` |

### Examples

```ruby
# Basic four-on-the-floor
runner.sound("bd hh sd hh")

# Sub-sequence
runner.sound("bd [hh hh] sd [hh bd]")

# Multiplication (faster hi-hats)
runner.sound("bd hh*2 sd hh*3")

# Parallel playback (drums and hi-hats)
runner.sound("bd sd, hh hh hh hh")

# Pattern with rests
runner.sound("bd - sd -")
```

## Running Demos

```bash
# Basic drum pattern demo
bundle exec ruby demo/first_sounds.rb

# Pattern collection demo
bundle exec ruby demo/patterns.rb

# Multi-track synth demo
bundle exec ruby demo/multi_track.rb

# Waveform showcase demo
bundle exec ruby demo/synth_demo.rb

# Custom functions (register) demo
bundle exec ruby demo/register_demo.rb
```

## Testing

```bash
bundle exec rspec
```

## Architecture

```
lib/strudel/
├── core/           # Pattern system
│   ├── fraction.rb    # Rational numbers (time precision)
│   ├── time_span.rb   # Time intervals
│   ├── hap.rb         # Events
│   ├── state.rb       # Query state
│   └── pattern.rb     # Pattern implementation
├── mini/           # Mini-Notation parser
│   └── parser.rb
├── audio/          # Audio output
│   ├── oscillator.rb    # Waveform generator (sine, sawtooth, square, triangle, supersaw)
│   ├── filter.rb        # Low-pass filter with envelope
│   ├── synth_player.rb  # Synthesizer playback
│   ├── sample_bank.rb   # Sample management
│   ├── sample_player.rb # Sample playback
│   └── vca.rb           # PortAudio stream
├── theory/         # Music theory
│   ├── note.rb        # Note name parsing (c4, f#3, etc.)
│   └── scale.rb       # Scale definitions and degree conversion
├── live/           # Live coding support
│   ├── file_watcher.rb    # File change detection
│   ├── pattern_evaluator.rb # Pattern evaluation
│   └── session.rb         # Live session management
├── scheduler/      # Scheduler
│   └── cyclist.rb
└── dsl.rb          # User-facing DSL (includes register function)
```

## References

- [Strudel](https://strudel.cc/) - Original JavaScript implementation
- [Tidal Cycles](https://tidalcycles.org/) - Haskell live coding environment
