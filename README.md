# strudel-rb

A Strudel-like live coding music library for Ruby.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Overview

strudel-rb is a Ruby library inspired by [Strudel](https://strudel.cc/) (the JavaScript implementation of Tidal Cycles). You can write drum patterns and melodic sequences in Mini-Notation, evaluate them on the fly, and hear changes the moment you save the file.

strudel-rb is an **independent implementation** written from scratch in Ruby against the public Strudel / Tidal Cycles language specifications and documentation. It is not a source-code port of Strudel; the Mini-Notation parser, the pattern engine, and the audio pipeline are original Ruby code. See [Acknowledgements](#acknowledgements) and [License](#license).

## Installation

```bash
bundle install
```

## Sample Files

### Local samples

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

### Remote samples (`samples` method)

The `samples` DSL loads sample packs from a GitHub repository, mirroring the [Strudel sample loading convention](https://strudel.cc/learn/samples/). The target repository must contain a `strudel.json` manifest at its root.

```ruby
# pattern.rb
samples("github:tidalcycles/dirt-samples")

sound("bd hh sd hh")
```

The source string takes the form `github:<user>/<repo>[/<branch>]`. The repository defaults to `samples` and the branch defaults to `main`. WAV files are downloaded on first use into `~/.cache/strudel-rb/samples/<user>/<repo>/` and reused on subsequent runs.

`strudel.json` follows the same shape used by [strudel.cc](https://strudel.cc/) — a map from sample name to one or more relative `.wav` paths, with an optional `_base` field:

```json
{
  "_base": "https://example.com/samples/",
  "bd": ["bd/BT0A0A7.wav", "bd/BT0A0D0.wav"],
  "hh": ["hh/000_hh3closedhh.wav"],
  "sd": "sd/snare.wav"
}
```

Within Mini-Notation, names registered in `strudel.json` are referenced directly. Variants are selected with `:n`:

```ruby
samples("github:tidalcycles/dirt-samples")

track(:drums) { sound("bd:0 hh sd:1 hh") }
track(:perc)  { sound("cp ~ cp ~").gain(0.6) }
```

You can also load multiple packs in one file; later `samples` calls add to the lookup chain, and local `samples/` files still take priority.

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

### `$:` track shorthand

For a terser live-coding feel that mirrors Strudel JS, you can write tracks with the `$:` prefix. A preprocessor rewrites these lines into `track` / `_track` calls before evaluation:

```ruby
$: sound("hh*8")                    # anonymous track
$:kick sound("bd*4").gain(0.3)      # named track (:kick)
_$:lead n("0 2 4 7").s("supersaw")  # muted track, toggle by removing the leading underscore
```

`$:` is `$LOAD_PATH` at the Ruby parser level and cannot be redefined, so this rewrite happens on the source string before it is evaluated. It is available inside pattern files run through `bin/strudel-watch`.

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

### Effects

Effects are managed **per orbit**, matching Strudel's design — each orbit has its own delay line, reverb, and duck envelope. Use `orbit` (alias `o`) to route voices.

```ruby
# Delay
sound("bd sd").delay(0.5).delaytime(0.25).delayfeedback(0.6)   # aliases: dt, dfb

# Reverb
sound("cp").room(0.6).roomsize(4)                              # aliases: rsize, sz, size

# Distortion
n("0 4 7").scale("c:minor").s("sawtooth").distort(4)           # alias: dist

# Ducking (sidechain-style) against another orbit
track(:drums) { sound("bd*4").orbit(0) }
track(:pad)   { note("c3 e3 g3").s("supersaw").orbit(1).duckorbit(0) }  # alias: duck
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

### Speech (`say`)

`say` turns text into a sound source via the system speech synthesizer (macOS `say`), so you can sequence spoken words like any other pattern:

```ruby
say("ruby kaigi", voice: "Kyoko").room(0.3).gain(0.8)
```

### MIDI input

External MIDI controllers can drive control values. Open a device and read a CC as a pattern:

```ruby
input = midi_input("IAC Driver Bus 1")
n("0 4 7").scale("c:minor").s("sawtooth").lpf(input.cc(7).mul(2000))
```

`demo/midi_cc.rb` and `demo/midi_monitor.rb` are runnable smoke tests.

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
bundle exec ruby demo/11_say.rb          # speech synthesis
bundle exec ruby demo/midi_cc.rb         # MIDI CC input smoke test
```

## Tools

- `bin/strudel-watch pattern.rb` — live-reload a pattern file and play it.
- `bin/strudel-browser [port]` — start a local WEBrick server to type Mini-Notation strings and inspect the resulting Hap events (defaults to `http://localhost:7000`).
- `bin/strudel-samples` — helper for working with sample packs.

## Testing

```bash
bundle exec rspec
```

## Architecture

```
lib/strudel/
├── core/        # Pattern, Hap, TimeSpan, Fraction, State
├── mini/        # Mini-Notation parser (Parslet)
├── audio/       # PortAudio output, oscillators, filters, effects, sample/synth players
├── theory/      # Note parsing and scales
├── midi/        # MIDI input (controllers, CC)
├── tts/         # Speech synthesis (say)
├── live/        # File watcher, pattern evaluator, session
├── scheduler/   # Cyclist (cycle scheduler)
├── bridge.rb    # JSON serialization for browser harness
└── dsl.rb       # User-facing DSL
```

## References

- [Strudel](https://strudel.cc/) — JavaScript implementation of Tidal Cycles
- [Mini-Notation](https://strudel.cc/learn/mini-notation/) — Syntax reference
- [Tidal Cycles](https://tidalcycles.org/) — Haskell live coding environment

## Acknowledgements

strudel-rb is inspired by and modeled on the language design of [Strudel](https://strudel.cc/) and [Tidal Cycles](https://tidalcycles.org/). The Mini-Notation syntax, the pattern/CPS model, and the DSL naming follow their published specifications and documentation so that patterns feel familiar to users of those tools.

strudel-rb does not incorporate source code from Strudel or Tidal Cycles. All Ruby code here — the Parslet-based Mini-Notation parser, the pattern engine, and the audio pipeline — is an independent implementation. Strudel and Tidal Cycles are wonderful projects, and strudel-rb exists thanks to the ideas they pioneered.

## License

Released under the [MIT License](LICENSE).

Copyright (c) 2026 Yuya Fujiwara.
