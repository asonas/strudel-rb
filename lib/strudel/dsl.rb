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

    module_function :register, :setcps, :setcpm, :setbpm

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
