# strudel-rb

A Strudel-like live coding music library for Ruby.

## Overview

strudel-rb is a Ruby library inspired by [Strudel](https://strudel.cc/) (the JavaScript implementation of Tidal Cycles). You can write drum patterns and melodic sequences in Mini-Notation, evaluate them on the fly, and hear changes the moment you save the file.

## Installation

```bash
bundle install
```

## Sample Files

Place WAV files under `samples/` using one directory per kit name:

```
samples/
├── bd/0.wav    # Bass drum
├── sd/0.wav    # Snare
├── hh/0.wav    # Hi-hat
├── cp/0.wav    # Clap
└── oh/0.wav    # Open hi-hat
```

Multiple variants (`bd/0.wav`, `bd/1.wav`, ...) are addressed with `:n` in Mini-Notation (e.g. `"bd:1"`).

## Quick Start

Write a pattern file and feed it to `bin/strudel-watch`. The file is reloaded automatically on save.

1. Create `pattern.rb`:

   ```ruby
   sound("bd hh sd hh")
   ```

2. Run the watcher:

   ```bash
   bin/strudel-watch pattern.rb
   ```

Edit `pattern.rb` and save. The new pattern starts at the next cycle boundary. Press `Ctrl+C` to stop.

`bin/strudel-watch` enables YJIT automatically via its shebang, so you do not need to prefix it with `bundle exec ruby`.

### A slightly larger example

```ruby
# pattern.rb
setcpm(120 / 4) # 120 bpm at 4 beats per cycle

track(:drums) { sound("bd hh sd hh") }
track(:bass)  { n("<0 4 7 4>").scale("c:minor").s("sawtooth").lpf(800) }
_track(:lead) { n("0 2 4 7").scale("c:minor").s("supersaw") } # muted; remove leading underscore to enable
```

- `track { ... }` registers a track. `_track { ... }` is the same but starts muted, which is handy when you want to toggle parts without commenting whole blocks out.
- Multiple `track` calls play in parallel.

## Tempo (CPS / BPM)

strudel-rb follows Strudel/Tidal's **CPS (cycles per second)** model. Set it at the top of your pattern file:

- `setcps(x)` — cycles per second
- `setcpm(x)` — cycles per minute (`setcps(x / 60.0)`)
- `setbpm(bpm, bpc:)` — derive cps from BPM and beats per cycle

The relationship is `bpm = cps * 60 * bpc`. With 4 beats per cycle, `setcpm(30)` gives 120 bpm.

Reference: [`setcps` (TidalCycles)](https://tidalcycles.org/docs/reference/tempo/#setcps)

## Patterns

### Synths

Available oscillators: `sine`, `sawtooth`, `square`, `triangle`, `supersaw`, `white`.

```ruby
note("c4 e4 g4").sound("sine")
n("0 4 7").scale("c:minor").s("sawtooth")
n("0").s("supersaw").detune(0.02)
```

### Filters and envelopes

```ruby
n("0 4 7").scale("c:minor").s("sawtooth")
  .lpf(400)    # cutoff (Hz)
  .lpenv(4)    # envelope depth (octaves)
  .lpa(0.01)   # attack
  .lpd(0.15)   # decay
  .lps(0.2)    # sustain
  .lpr(0.2)    # release
  .lpq(8)      # resonance (Q)
```

### Scales and transpose

```ruby
n("0 2 4").scale("c:major").s("sine")
n("0 4 7").scale("c:major").trans(-12).s("sine") # one octave down
```

Available scales: `major`, `minor`, `dorian`, `phrygian`, `lydian`, `mixolydian`, `locrian`, `chromatic`, `pentatonic`, `blues`, `wholetone`.

### Custom transformations (`register`)

```ruby
register(:rlpf) do |x, pat|
  pat.lpf(Pattern.pure(x).mul(12).pow(4))
end

n("<0 4 7>*8").scale("a:minor").s("sawtooth").rlpf(0.6)
```

### Random values

```ruby
n("0").s("supersaw").detune(rand.mul(0.05))
irand(8).scale("c:pentatonic").s("sine")
```

### Strudel-style string operators (Ruby::Box, optional)

To use arithmetic methods directly on bare strings, like `"0 2 4".add("<0 3 4 0>")`, run the watcher with `RUBY_BOX=1`. The monkey patch is scoped to a single evaluation via Ruby 4.0's experimental `Ruby::Box` and does not leak.

```bash
RUBY_BOX=1 bin/strudel-watch pattern.rb
```

```ruby
n("0 2 4".add("<0 3 4 0>")).scale("c:major").s("sawtooth")
gain("0.5 0.7".mul("0.8"))
```

Without `RUBY_BOX=1`, this syntax is unavailable but the rest of the DSL works as usual.

## Mini-Notation

strudel-rb implements a subset of Strudel's Mini-Notation. For the full syntax reference, see the official documentation:

- [Mini-Notation — strudel.cc](https://strudel.cc/learn/mini-notation/)

A short cheat sheet of what is supported here:

| Syntax | Meaning |
|--------|---------|
| `bd hh sd` | Sequence |
| `bd*2` | Speed up (n times faster) |
| `bd!3` | Replicate (n copies) |
| `bd/2` | Slow down |
| `[bd hh]` | Group |
| `<a b c>` | One element per cycle |
| `bd, hh*4` | Parallel stack |
| `bd:2` | Sample number |
| `~` or `-` | Rest |
| `_` | Hold previous event |

## Running Demos

```bash
bundle exec ruby demo/first_sounds.rb
bundle exec ruby demo/multi_track.rb
bundle exec ruby demo/synth_demo.rb
bundle exec ruby demo/register_demo.rb
```

## Testing

```bash
bundle exec rspec
```

## Architecture

```
lib/strudel/
├── core/        # Pattern, Hap, TimeSpan, Fraction, State
├── mini/        # Mini-Notation parser (Parslet)
├── audio/       # PortAudio output, oscillators, filters, sample/synth players
├── theory/      # Note parsing and scales
├── live/        # File watcher, pattern evaluator, session
├── scheduler/   # Cyclist (cycle scheduler)
├── bridge.rb    # JSON serialization for browser harness
└── dsl.rb       # User-facing DSL
```

## References

- [Strudel](https://strudel.cc/) — Original JavaScript implementation
- [Mini-Notation](https://strudel.cc/learn/mini-notation/) — Syntax reference
- [Tidal Cycles](https://tidalcycles.org/) — Haskell live coding environment
