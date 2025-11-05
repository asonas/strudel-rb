# frozen_string_literal: true

module Strudel
  module DSL
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
    def n(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      pattern.with_value { |v| { n: v.to_i } }
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
  end

  # Runner class: Makes it easy to play patterns using DSL
  class Runner
    include DSL

    def initialize(samples_path: nil, cps: 0.5)
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
