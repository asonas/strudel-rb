# frozen_string_literal: true

module Strudel
  module Audio
    class Oscillator
      WAVEFORMS = %i[sine sawtooth square triangle supersaw].freeze
      SUPERSAW_VOICES = 7
      DEFAULT_SUPERSAW_DETUNE = 0.01

      attr_accessor :detune

      def initialize(waveform = :sine, sample_rate: 44_100, detune: DEFAULT_SUPERSAW_DETUNE)
        unless WAVEFORMS.include?(waveform)
          raise ArgumentError, "Unknown waveform: #{waveform}. Use one of: #{WAVEFORMS.join(', ')}"
        end

        @waveform = waveform
        @sample_rate = sample_rate
        @phase = 0.0
        @detune = detune
        # For supersaw: separate phases for each voice
        @supersaw_phases = Array.new(SUPERSAW_VOICES, 0.0)
      end

      def generate(frequency:, frame_count:)
        phase_increment = frequency / @sample_rate.to_f

        if @waveform == :supersaw
          generate_supersaw(frequency, frame_count)
        else
          Array.new(frame_count) do
            sample = generate_sample(@phase)
            @phase = (@phase + phase_increment) % 1.0
            sample
          end
        end
      end

      def reset
        @phase = 0.0
        @supersaw_phases = Array.new(SUPERSAW_VOICES, 0.0)
      end

      private

      def generate_sample(phase)
        case @waveform
        when :sine
          Math.sin(2 * Math::PI * phase)
        when :sawtooth
          2.0 * phase - 1.0
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
        # Calculate detune offsets for each voice (-3, -2, -1, 0, 1, 2, 3)
        center = SUPERSAW_VOICES / 2
        detune_factors = SUPERSAW_VOICES.times.map do |i|
          1.0 + (i - center) * @detune
        end

        Array.new(frame_count) do
          sum = 0.0

          SUPERSAW_VOICES.times do |i|
            freq = base_frequency * detune_factors[i]
            phase_increment = freq / @sample_rate.to_f

            # Generate sawtooth sample
            sum += 2.0 * @supersaw_phases[i] - 1.0

            # Update phase
            @supersaw_phases[i] = (@supersaw_phases[i] + phase_increment) % 1.0
          end

          # Normalize by number of voices
          sum / SUPERSAW_VOICES
        end
      end
    end
  end
end
