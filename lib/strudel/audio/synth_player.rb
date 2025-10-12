# frozen_string_literal: true

module Strudel
  module Audio
    class SynthPlayer
      attr_reader :playing

      # A4 = 440Hz, MIDI note 69
      A4_FREQUENCY = 440.0
      A4_MIDI_NOTE = 69

      def initialize(waveform = :sine, sample_rate: 44_100, decay: 1.0, gain: 1.0)
        @oscillator = Oscillator.new(waveform, sample_rate: sample_rate)
        @sample_rate = sample_rate
        @decay = decay
        @gain = gain
        @playing = false
        @frequency = 440.0
        @elapsed_samples = 0
      end

      def trigger(frequency: nil, note: nil, gain: nil)
        @frequency = if note
                       midi_to_frequency(note)
                     elsif frequency
                       frequency
                     else
                       440.0
                     end
        @gain = gain if gain
        @elapsed_samples = 0
        @oscillator.reset
        @playing = true
      end

      def stop
        @playing = false
      end

      def playing?
        @playing
      end

      def generate(frame_count)
        return Array.new(frame_count, 0.0) unless @playing

        samples = @oscillator.generate(frequency: @frequency, frame_count: frame_count)

        # Apply decay envelope
        samples.map!.with_index do |sample, i|
          elapsed_time = (@elapsed_samples + i) / @sample_rate.to_f
          envelope = decay_envelope(elapsed_time)

          if envelope <= 0.001
            @playing = false
            0.0
          else
            sample * envelope * @gain
          end
        end

        @elapsed_samples += frame_count
        samples
      end

      private

      def midi_to_frequency(note)
        A4_FREQUENCY * (2.0**((note - A4_MIDI_NOTE) / 12.0))
      end

      def decay_envelope(time)
        # Simple exponential decay
        Math.exp(-time / @decay)
      end
    end
  end
end
