# frozen_string_literal: true

module Strudel
  module Audio
    # Orbit-level ducking envelope (sidechain-like).
    #
    # When triggered, gain ramps down to (1 - depth) over `onset` seconds,
    # then ramps back to 1 over `attack` seconds.
    class DuckEnvelope
      def initialize(sample_rate:)
        @sample_rate = sample_rate
        reset
      end

      def reset
        @active = false
        @samples_in_stage = 0
        @onset_samples = 0
        @attack_samples = 0
        @min_gain = 1.0
      end

      def trigger(onset:, attack:, depth:)
        depth = depth.to_f.clamp(0.0, 1.0)
        @min_gain = 1.0 - depth
        @onset_samples = (onset.to_f * @sample_rate).to_i
        @attack_samples = (attack.to_f * @sample_rate).to_i
        @samples_in_stage = 0
        @active = true
      end

      def process(frame_count)
        gains = Array.new(frame_count, 1.0)
        return gains unless @active

        frame_count.times do |i|
          gains[i] = gain_at(@samples_in_stage)
          @samples_in_stage += 1
        end

        end_samples = @onset_samples + @attack_samples
        @active = false if @samples_in_stage >= end_samples

        gains
      end

      private

      def lerp(a, b, t)
        a + (b - a) * t
      end

      def gain_at(sample_index)
        return 1.0 if @onset_samples.zero? && @attack_samples.zero?

        end_samples = @onset_samples + @attack_samples
        return 1.0 if sample_index >= end_samples

        if sample_index < @onset_samples
          t = @onset_samples.zero? ? 1.0 : sample_index.to_f / @onset_samples
          lerp(1.0, @min_gain, t.clamp(0.0, 1.0))
        else
          rel_i = sample_index - @onset_samples
          t = @attack_samples.zero? ? 1.0 : rel_i.to_f / @attack_samples
          lerp(@min_gain, 1.0, t.clamp(0.0, 1.0))
        end
      end
    end
  end
end
