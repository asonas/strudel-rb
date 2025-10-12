# frozen_string_literal: true

module Strudel
  module Audio
    class Oscillator
      WAVEFORMS = %i[sine sawtooth square triangle].freeze

      def initialize(waveform = :sine, sample_rate: 44_100)
        unless WAVEFORMS.include?(waveform)
          raise ArgumentError, "Unknown waveform: #{waveform}. Use one of: #{WAVEFORMS.join(', ')}"
        end

        @waveform = waveform
        @sample_rate = sample_rate
        @phase = 0.0
      end

      def generate(frequency:, frame_count:)
        phase_increment = frequency / @sample_rate.to_f

        Array.new(frame_count) do
          sample = generate_sample(@phase)
          @phase = (@phase + phase_increment) % 1.0
          sample
        end
      end

      def reset
        @phase = 0.0
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
    end
  end
end
