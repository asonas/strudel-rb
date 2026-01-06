# frozen_string_literal: true

module Strudel
  module Audio
    class Oscillator
      WAVEFORMS = %i[sine sawtooth square triangle supersaw white].freeze
      # Match Strudel(superdough) default supersaw voices.
      SUPERSAW_VOICES = 5
      # Match Strudel(superdough) default detune (= freqspread, semitones).
      DEFAULT_SUPERSAW_DETUNE = 0.18

      attr_accessor :detune

      def initialize(waveform = :sine, sample_rate: 44_100, detune: DEFAULT_SUPERSAW_DETUNE, voices: nil)
        unless WAVEFORMS.include?(waveform)
          raise ArgumentError, "Unknown waveform: #{waveform}. Use one of: #{WAVEFORMS.join(', ')}"
        end

        @waveform = waveform
        @sample_rate = sample_rate
        @phase = 0.0
        @detune = detune
        @noise_rng = Random.new
        @supersaw_voices = (voices || SUPERSAW_VOICES).to_i.clamp(1, 100)
        # For supersaw: separate phases for each voice
        @supersaw_phases = Array.new(@supersaw_voices) { Random.rand }
      end

      def generate(frequency:, frame_count:)
        if @waveform == :white
          return Array.new(frame_count) { @noise_rng.rand * 2.0 - 1.0 }
        end

        phase_increment = frequency / @sample_rate.to_f

        if @waveform == :supersaw
          generate_supersaw(frequency, frame_count)
        else
          @last_dt = phase_increment
          Array.new(frame_count) do
            sample = generate_sample(@phase)
            @phase = (@phase + phase_increment) % 1.0
            sample
          end
        end
      end

      # Generate a single sample with a possibly time-varying frequency.
      def step(frequency)
        frequency = frequency.to_f
        return @noise_rng.rand * 2.0 - 1.0 if @waveform == :white

        if @waveform == :supersaw
          step_supersaw(frequency)
        else
          dt = frequency / @sample_rate.to_f
          @last_dt = dt
          sample = generate_sample(@phase)
          @phase = (@phase + dt) % 1.0
          sample
        end
      end

      def reset
        @phase = 0.0
        @supersaw_phases = Array.new(@supersaw_voices) { Random.rand }
      end

      private

      # polyBLEP antialiasing (ported from Strudel/supradough)
      def poly_blep(t, dt)
        return 0.0 if dt <= 0.0

        if t < dt
          x = t / dt
          return x + x - x * x - 1.0
        end

        if t > 1.0 - dt
          x = (t - 1.0) / dt
          return x * x + x + x + 1.0
        end

        0.0
      end

      def generate_sample(phase)
        case @waveform
        when :sine
          Math.sin(2 * Math::PI * phase)
        when :sawtooth
          dt = @last_dt || 0.0
          (2.0 * phase - 1.0) - poly_blep(phase, dt)
        when :square
          phase < 0.5 ? 1.0 : -1.0
        when :triangle
          if phase < 0.25
            4.0 * phase
          elsif phase < 0.75
            2.0 - 4.0 * phase
          else
            4.0 * phase - 4.0
          end
        end
      end

      # Generate supersaw: multiple detuned sawtooth waves
      def generate_supersaw(base_frequency, frame_count)
        # Spread voices in semitones across [-detune/2, +detune/2]
        detune = @detune.to_f
        voices = @supersaw_voices
        denom = (voices - 1).to_f
        semitone_offsets = voices.times.map do |i|
          denom.zero? ? 0.0 : (-detune * 0.5) + (detune * (i / denom))
        end

        Array.new(frame_count) do
          sum = 0.0

          voices.times do |i|
            freq = base_frequency * (2.0**(semitone_offsets[i] / 12.0))
            phase_increment = freq / @sample_rate.to_f
            dt = phase_increment

            # Generate sawtooth sample
            phase = @supersaw_phases[i]
            sum += (2.0 * phase - 1.0) - poly_blep(phase, dt)

            # Update phase
            @supersaw_phases[i] = (@supersaw_phases[i] + phase_increment) % 1.0
          end

          # Energy normalization (matches superdough's 1/sqrt(voices) adjustment more closely than averaging)
          sum / Math.sqrt(voices)
        end
      end

      def step_supersaw(base_frequency)
        detune = @detune.to_f
        voices = @supersaw_voices
        denom = (voices - 1).to_f
        semitone_offsets = voices.times.map do |i|
          denom.zero? ? 0.0 : (-detune * 0.5) + (detune * (i / denom))
        end

        sum = 0.0
        voices.times do |i|
          freq = base_frequency * (2.0**(semitone_offsets[i] / 12.0))
          dt = freq / @sample_rate.to_f
          phase = @supersaw_phases[i]
          sum += (2.0 * phase - 1.0) - poly_blep(phase, dt)
          @supersaw_phases[i] = (phase + dt) % 1.0
        end
        sum / Math.sqrt(voices)
      end
    end
  end
end
