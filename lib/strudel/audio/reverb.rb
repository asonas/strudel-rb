# frozen_string_literal: true

module Strudel
  module Audio
    # Simple Feedback Delay Network (FDN) reverb
    # Applied per-orbit in Cyclist, controlled by room (wet) and roomsize parameters
    class Reverb
      attr_reader :wet, :roomsize

      # Prime delay line lengths (in samples at 44100 Hz) for diffusion
      DELAY_LENGTHS_44100 = [1117, 1357, 1493, 1693].freeze
      NUM_LINES = DELAY_LENGTHS_44100.length

      def initialize(sample_rate: 44_100)
        @sample_rate = sample_rate
        @wet = 0.0
        @roomsize = 1.0
        @feedback = 0.5

        # Scale delay lengths for the actual sample rate
        scale = sample_rate / 44_100.0
        @delay_lengths = DELAY_LENGTHS_44100.map { |l| (l * scale).to_i.clamp(1, 100_000) }

        # Delay buffers and write positions
        @buffers_l = @delay_lengths.map { |l| Array.new(l, 0.0) }
        @buffers_r = @delay_lengths.map { |l| Array.new(l, 0.0) }
        @positions = Array.new(NUM_LINES, 0)

        # One-pole damping filters per line
        @damp_l = Array.new(NUM_LINES, 0.0)
        @damp_r = Array.new(NUM_LINES, 0.0)
        @damp_coeff = 0.3
      end

      def configure(wet:, roomsize:)
        @wet = wet.to_f.clamp(0.0, 1.0)
        @roomsize = roomsize.to_f.clamp(0.0, 10.0)
        # Feedback derived from roomsize: larger room = more feedback
        @feedback = (0.3 + @roomsize * 0.065).clamp(0.0, 0.95)
        # Damping: larger room = less high-frequency damping
        @damp_coeff = (0.5 - @roomsize * 0.03).clamp(0.05, 0.8)
      end

      def process(input_l, input_r)
        return [input_l, input_r] if @wet <= 0.0

        dry_mix = 1.0
        wet_mix = @wet

        out_l = Array.new(input_l.length, 0.0)
        out_r = Array.new(input_r.length, 0.0)

        input_l.length.times do |i|
          dry_l = input_l[i]
          dry_r = input_r[i]

          # Read from delay lines
          wet_l = 0.0
          wet_r = 0.0

          NUM_LINES.times do |n|
            pos = @positions[n]
            len = @delay_lengths[n]

            # Read delayed sample
            read_l = @buffers_l[n][pos]
            read_r = @buffers_r[n][pos]

            # One-pole damping filter
            @damp_l[n] = @damp_l[n] + @damp_coeff * (read_l - @damp_l[n])
            @damp_r[n] = @damp_r[n] + @damp_coeff * (read_r - @damp_r[n])

            wet_l += @damp_l[n]
            wet_r += @damp_r[n]

            # Write new input + feedback into delay line
            # Use Householder matrix mixing: simple approximation with cross-feed
            cross = n.even? ? dry_r : dry_l
            @buffers_l[n][pos] = (dry_l + cross * 0.1 + @damp_l[n] * @feedback).clamp(-2.0, 2.0)
            @buffers_r[n][pos] = (dry_r + cross * 0.1 + @damp_r[n] * @feedback).clamp(-2.0, 2.0)

            @positions[n] = (pos + 1) % len
          end

          # Normalize wet signal
          wet_l /= NUM_LINES
          wet_r /= NUM_LINES

          out_l[i] = dry_l * dry_mix + wet_l * wet_mix
          out_r[i] = dry_r * dry_mix + wet_r * wet_mix
        end

        [out_l, out_r]
      end

      def reset
        @buffers_l.each { |b| b.fill(0.0) }
        @buffers_r.each { |b| b.fill(0.0) }
        @positions.fill(0)
        @damp_l.fill(0.0)
        @damp_r.fill(0.0)
      end
    end
  end
end
