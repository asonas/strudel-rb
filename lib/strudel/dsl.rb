# frozen_string_literal: true

module Strudel
  module DSL
    TrackEntry = Data.define(:name, :pattern, :muted)

    # ---- Track DSL (Strudel-like $:) ----
    #
    # In Strudel, `$:` definitions are automatically stacked and can be muted with `_$:`.
    # Ruby cannot override `$:` (it's $LOAD_PATH), so we provide `track` / `_track` instead.
    #
    # Example:
    #   track { sound("bd") }
    #   _track { sound("hh") } # muted
    #   tracks # => Pattern.stack(...)
    def track(name = nil, &block)
      register_track(name, muted: false, &block)
    end

    def _track(name = nil, &block)
      register_track(name, muted: true, &block)
    end

    # Returns a pattern composed of all non-muted tracks.
    #
    # In live coding, a single broken track shouldn't silence the whole session.
    # We therefore query tracks independently and drop only the failing one.
    def tracks
      entries = track_registry.values.reject(&:muted)
      return Pattern.silence if entries.empty?

      Pattern.new do |state|
        entries.flat_map do |entry|
          begin
            entry.pattern.query(state)
          rescue StandardError => e
            warn "[#{entry.name}] Error querying track: #{e.class}: #{e.message}"
            []
          end
        end
      end
    end

    # Clears track registry (useful for live reload).
    def clear_tracks
      @track_registry = {}
      @track_auto_index = 0
    end

    def track_registry
      @track_registry ||= {}
    end

    def next_track_name
      @track_auto_index ||= 0
      @track_auto_index += 1
      :"track#{@track_auto_index}"
    end

    def register_track(name, muted:, &block)
      raise ArgumentError, "block is required" unless block

      name ||= next_track_name
      pat = instance_exec(&block)
      unless pat.is_a?(Pattern)
        raise TypeError, "track block must return a Strudel::Pattern (got #{pat.class})"
      end

      track_registry[name] = TrackEntry.new(name, pat, muted)
      pat
    end

    private :track_registry, :next_track_name, :register_track

    # ---- Tempo (global) ----
    #
    # Strudel/Tidal expresses tempo in CPS (cycles per second).
    # These functions change the global tempo that new Runner/Session instances pick up.
    #
    # See: https://tidalcycles.org/docs/reference/tempo/#setcps
    def setcps(value)
      Strudel.setcps(value)
    end

    def setcpm(value)
      Strudel.setcpm(value)
    end

    # Convenience: set bpm by assuming "beats per cycle" (bpc).
    # Common 4/4 interpretation is bpc=4.
    def setbpm(bpm, bpc: 4)
      Strudel.setbpm(bpm, bpc: bpc)
    end

    # Create a pattern using sound("bd hh sd hh") notation
    def sound(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      # Convert values to sound information
      pattern.with_value do |v|
        case v
        when String
          { s: v, n: 0 }
        when Hash
          v[:s] ? v : { s: v.to_s, n: 0 }
        else
          { s: v.to_s, n: 0 }
        end
      end
    end

    alias_method :s, :sound

    # Notation like n("0 1 2 3").sound("jazz")
    # Also used for scale degrees: n("<0 4 7>").scale("c:minor")
    def n(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      pattern.with_value do |v|
        v.nil? ? nil : v.to_i
      end
    end

    # Notation like note("c4 e4 g4")
    def note(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      pattern.with_value do |v|
        midi_note = Theory::Note.parse(v)
        { note: midi_note || v }
      end
    end

    # Silence (no sound)
    def silence
      Pattern.silence
    end

    # Stack (parallel playback)
    def stack(*patterns)
      Pattern.stack(*patterns)
    end

    # Sequence
    def sequence(*patterns)
      Pattern.sequence(*patterns)
    end

    # Fastcat (alias for sequence)
    def fastcat(*patterns)
      Pattern.fastcat(*patterns)
    end

    # Slowcat (one per cycle)
    def slowcat(*patterns)
      Pattern.slowcat(*patterns)
    end

    # Cat (alias for fastcat)
    def cat(*patterns)
      Pattern.fastcat(*patterns)
    end

    # Pure (single value pattern)
    def pure(value)
      Pattern.pure(value)
    end

    # Gain pattern
    def gain(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      pattern.with_value { |v| v.to_f }
    end

    # Speed pattern
    def speed(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      pattern.with_value { |v| v.to_f }
    end

    # Pan pattern
    def pan(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      pattern.with_value { |v| v.to_f }
    end

    # Euclidean rhythm
    def euclid(pulses, steps, rotation = 0)
      Pattern.euclid(pulses, steps, rotation)
    end

    # Random pattern (0.0 to 1.0)
    # Returns a different random value for each event
    def rand
      Pattern.new do |state|
        t = state.span.begin_time.to_f
        value = time_to_rand(t)
        # Keep whole present so the caller pattern's onsets are preserved through set_control
        [Hap.new(state.span, state.span, value)]
      end
    end

    # Integer random pattern (0 to n-1)
    def irand(n)
      rand.fmap { |v| (v * n).to_i }
    end

    # ---- Signal Patterns ----

    # Triangle wave: 0 -> 1 -> 0 over one cycle
    def tri
      Pattern.new do |state|
        t = state.span.begin_time.to_f
        cycle_pos = t - t.floor
        value = 1.0 - (2.0 * (cycle_pos - 0.5)).abs
        [Hap.new(state.span, state.span, value)]
      end
    end

    # Sawtooth wave: 0 -> 1 linearly over one cycle
    def saw
      Pattern.new do |state|
        t = state.span.begin_time.to_f
        value = t - t.floor
        [Hap.new(state.span, state.span, value)]
      end
    end

    # Sine wave: oscillates between 0 and 1
    def sine
      Pattern.new do |state|
        t = state.span.begin_time.to_f
        cycle_pos = t - t.floor
        value = (1.0 + Math.sin(2.0 * Math::PI * cycle_pos)) / 2.0
        [Hap.new(state.span, state.span, value)]
      end
    end

    # Square wave: 1 for first half, 0 for second half
    def square
      Pattern.new do |state|
        t = state.span.begin_time.to_f
        cycle_pos = t - t.floor
        value = cycle_pos < 0.5 ? 1.0 : 0.0
        [Hap.new(state.span, state.span, value)]
      end
    end

    # Register a custom function on Pattern
    # Usage:
    #   register(:acidenv) do |x, pat|
    #     pat.lpf(800)
    #   end
    #
    #   n("0 4 7").s("sawtooth").acidenv(0.6)
    def register(name, &block)
      Pattern.define_method(name) do |*args|
        block.call(*args, self)
      end
    end

    # ---- Arrange Functions ----

    # Stepcat: concatenate patterns proportionally by step count.
    # Each section is [steps, pattern].
    def stepcat(*sections)
      total = sections.sum { |steps, _| steps.to_r }

      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          cycle = subspan.begin_time.sam
          pos = Rational(0)

          sections.flat_map do |steps, pattern|
            pattern = Pattern.reify(pattern)
            frac = steps.to_r / total

            sect_begin = cycle + Fraction.new(pos)
            sect_end = cycle + Fraction.new(pos + frac)
            sect_span = TimeSpan.new(sect_begin, sect_end)

            intersection = sect_span.intersection(subspan)
            pos += frac
            next [] unless intersection

            scale_factor = Rational(1) / frac

            inner_begin = cycle + Fraction.new((intersection.begin_time.value - sect_begin.value) * scale_factor)
            inner_end = cycle + Fraction.new((intersection.end_time.value - sect_begin.value) * scale_factor)
            inner_span = TimeSpan.new(inner_begin, inner_end)

            pattern.query(state.set_span(inner_span)).map do |hap|
              remap = ->(t) {
                inner_pos = t.value - cycle.value
                Fraction.new(sect_begin.value + inner_pos * frac)
              }

              new_whole = hap.whole && TimeSpan.new(remap.call(hap.whole.begin_time), remap.call(hap.whole.end_time))
              new_part = TimeSpan.new(remap.call(hap.part.begin_time), remap.call(hap.part.end_time))

              Hap.new(new_whole, new_part, hap.value, hap.context)
            end
          end
        end
      end
    end

    # Ar (Quick Arrange): play sections sequentially for given cycle counts.
    # Usage: ar(16, intro, 16, break1, 32, drop)
    def ar(*input)
      sects = []
      total = 0

      input.each_slice(2) do |cycles, pattern|
        total += cycles
        sects << [cycles, pattern.ribbon(0, cycles).fast(cycles)]
      end

      stepcat(*sects).slow(total)
    end

    # BlockArrange: control track ON/OFF/reverse per cycle with mask patterns.
    # pat_arr: [[pattern, mask_pattern], ...]
    # mask values: "F" = forward, "0" = silence, "B" = backwards, "R" = restart
    def block_arrange(pat_arr, modifiers = [])
      tracks = pat_arr.map do |pat, mask_pat|
        pats = pat.is_a?(Array) ? pat : [pat]
        mask_pat = Pattern.reify(mask_pat)

        mask_pat.fmap do |m|
          next Pattern.silence if m.to_s == "0"

          ms = m.to_s
          inner = Pattern.stack(*pats.map do |p|
            new_pat = p
            new_pat = new_pat.restart(1) if ms.include?("R")
            new_pat = new_pat.rev.speed(-1) if ms.include?("B")
            modifiers.each do |mod_check, callback|
              new_pat = callback.call(new_pat) if mod_check.call(ms)
            end
            new_pat
          end)

          inner
        end.inner_join
      end

      Pattern.stack(*tracks.flatten)
    end

    module_function :register, :setcps, :setcpm, :setbpm

    # ---- Built-in register functions (Phase 5) ----

    # Normalized low-pass filter: x in 0-1, maps to cutoff = (x*12)^4
    register(:rlpf) do |x, pat|
      pat.lpf(Pattern.pure(x).mul(12).pow(4))
    end

    # Normalized high-pass filter: x in 0-1, maps to cutoff = (x*12)^4
    register(:rhpf) do |x, pat|
      pat.hpf(Pattern.pure(x).mul(12).pow(4))
    end

    # Trancegate: random gate pattern applied to a sound.
    # density: gate density (0-1 range, 0.5 added internally)
    # seed: ribbon offset for pattern variety
    # length: ribbon length for pattern variety
    register(:trancegate) do |density, seed, length, pat|
      density_pat = Pattern.reify(density).add(0.5)
      # Generate gate structure using deterministic random + segment + ribbon
      gate = Pattern.new { |state|
        t = state.span.begin_time.to_f
        value = Pattern.send(:time_to_rand, t)
        [Hap.new(state.span, state.span, value)]
      }.mul(density_pat).round.seg(16).rib(seed, length)

      pat.struct(gate).fill.clip(0.7)
    end

    # Polyphonic pitch glide: smoothly slides pitch from previous note to current.
    # time: glide duration in seconds
    register(:glide) do |time, pat|
      curr = []
      prev = []
      last_t = nil

      # Convert hap value to frequency (mirrors Strudel's getFrequencyFromValue)
      freq_from = ->(value) {
        return nil unless value.is_a?(Hash)

        note = value[:note] || 36
        freq = value[:freq]
        note = Theory::Note.parse(note) || 36 if note.is_a?(String)
        freq ||= 440.0 * (2.0**((note.to_f - 69) / 12.0)) if note.is_a?(Numeric)
        freq
      }

      Pattern.new do |state|
        haps = pat.query(state)
        output = []

        haps.each do |hap|
          next output << hap unless hap.value.is_a?(Hash)

          t = hap.whole&.begin_time&.to_f
          if t && (last_t.nil? || last_t != t)
            prev = curr.dup
            curr = []
            last_t = t
          end

          freq = freq_from.call(hap.value)
          curr << freq if freq

          new_value = hap.value.merge(pdecay: time)

          if freq && prev.any?
            closest = prev.min_by { |f| (f - freq).abs }
            if (closest - freq).abs > 1e-6
              penv = -12.0 * Math.log2(freq / closest)
              new_value = new_value.merge(penv: penv, pattack: 0, psustain: 0, panchor: 0)
            end
          end

          output << Hap.new(hap.whole, hap.part, new_value, hap.context)
        end

        output
      end
    end

    private

    # Port of Strudel's timeToRand (packages/core/signal.mjs)
    # - deterministic pseudo-random value for a given time in cycles
    # - returns a Float in 0..1
    def time_to_rand(x)
      int_seed_to_rand(time_to_int_seed(x)).abs
    end

    # stretch 300 cycles over the range of [0, 2**29) then apply the xorshift algorithm
    def time_to_int_seed(x)
      t = x / 300.0
      frac = t - t.truncate
      seed = (frac * 536_870_912).truncate
      xorwise(seed)
    end

    def int_seed_to_rand(x)
      (x.remainder(536_870_912) / 536_870_912.0)
    end

    def xorwise(x)
      a = int32((x << 13) ^ x)
      b = int32((a >> 17) ^ a)
      int32((b << 5) ^ b)
    end

    # Emulate JavaScript's 32-bit signed bitwise behavior.
    def int32(n)
      n &= 0xFFFF_FFFF
      n >= 0x8000_0000 ? n - 0x1_0000_0000 : n
    end
  end

  # Runner class: Makes it easy to play patterns using DSL
  class Runner
    include DSL

    def initialize(samples_path: nil, cps: Strudel.cps)
      @samples_path = samples_path
      @cps = cps
      @scheduler = nil
      @vca = nil
    end

    def play(pattern)
      setup_audio unless @vca

      @scheduler.set_pattern(pattern)
      @vca.start unless @vca.running?
    end

    def stop
      @vca&.stop
      @scheduler&.reset
    end

    def cps=(value)
      @cps = value
      @scheduler.cps = value if @scheduler
    end

    def setup_audio
      Audio::VCA.initialize_audio
      @scheduler = Scheduler::Cyclist.new(
        cps: @cps,
        samples_path: @samples_path
      )
      @vca = Audio::VCA.new(@scheduler)
    end

    def cleanup
      @vca&.stop
      @vca&.close
      Audio::VCA.terminate_audio
    end
  end
end
