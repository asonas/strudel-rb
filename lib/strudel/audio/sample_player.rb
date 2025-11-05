# frozen_string_literal: true

module Strudel
  module Audio
    class SamplePlayer
      attr_reader :playing

      def initialize(sample_data, target_sample_rate = 44_100)
        @sample_data = sample_data
        @target_sample_rate = target_sample_rate
        @position = 0.0
        @playing = false
        @gain = 1.0
        @speed = 1.0

        # Base sample rate conversion ratio
        @base_rate_ratio = sample_data.sample_rate.to_f / target_sample_rate
      end

      # Start playback
      def trigger(gain: 1.0, speed: 1.0)
        @position = 0.0
        @playing = true
        @gain = gain
        @speed = speed
      end

      # Stop playback
      def stop
        @playing = false
      end

      # Check if playing
      def playing?
        @playing
      end

      # Generate audio samples
      def generate(frame_count)
        return Array.new(frame_count, 0.0) unless @playing
        return Array.new(frame_count, 0.0) if @sample_data.empty?

        samples = @sample_data.samples
        output = Array.new(frame_count, 0.0)

        # Rate ratio considering speed
        rate_ratio = @base_rate_ratio * @speed.abs

        frame_count.times do |i|
          idx = @position.to_i

          if idx >= samples.length || idx < 0
            @playing = false
            break
          end

          # Get sample value using linear interpolation
          frac = @position - idx
          current = samples[idx] || 0.0
          next_sample = samples[idx + 1] || current
          output[i] = (current + (next_sample - current) * frac) * @gain

          # For reverse playback (negative speed), move in reverse direction
          @position += @speed >= 0 ? rate_ratio : -rate_ratio
        end

        output
      end
    end
  end
end
