# frozen_string_literal: true

module Strudel
  module Audio
    # Simple stereo feedback delay line.
    #
    # This is used as an orbit-level effect (Strudel/superdough style).
    class DelayLine
      MAX_DELAY_SECONDS = 10.0

      def initialize(sample_rate:)
        @sample_rate = sample_rate
        @max_samples = (MAX_DELAY_SECONDS * @sample_rate).to_i
        @buffer_l = Array.new(@max_samples, 0.0)
        @buffer_r = Array.new(@max_samples, 0.0)
        @write_pos = 0

        @wet = 0.0
        @time = 0.25
        @feedback = 0.5
      end

      def configure(wet:, time:, feedback:)
        @wet = wet.to_f.clamp(0.0, 1.0)
        @time = time.to_f.clamp(0.0, MAX_DELAY_SECONDS)
        @feedback = feedback.to_f.clamp(0.0, 0.999)
      end

      def process(left, right)
        delay_samples = (@time * @sample_rate).to_i
        delay_samples = delay_samples.clamp(1, @max_samples - 1)

        out_l = Array.new(left.length, 0.0)
        out_r = Array.new(right.length, 0.0)

        left.length.times do |i|
          read_pos = @write_pos - delay_samples
          read_pos += @max_samples if read_pos.negative?

          dl = @buffer_l[read_pos]
          dr = @buffer_r[read_pos]

          dry_l = left[i].to_f
          dry_r = right[i].to_f

          out_l[i] = dry_l + dl * @wet
          out_r[i] = dry_r + dr * @wet

          @buffer_l[@write_pos] = dry_l + dl * @feedback
          @buffer_r[@write_pos] = dry_r + dr * @feedback

          @write_pos += 1
          @write_pos = 0 if @write_pos >= @max_samples
        end

        [out_l, out_r]
      end
    end
  end
end
