# frozen_string_literal: true

module Strudel
  module Audio
    class TTSPlayer
      attr_reader :playing

      def initialize(generator, sample_rate = 44_100)
        @generator = generator
        @sample_rate = sample_rate
        @position = 0.0
        @playing = false
        @gain = 1.0
        @speed = 1.0
        @elapsed_samples = 0
        @released = false
        @hold_duration = nil
        @audio_data = nil
        @amp_envelope = ADSREnvelope.new(sample_rate: sample_rate)
        @hpf_l = HighPassFilter.new(sample_rate: sample_rate, cutoff: 20.0)
        @hpf_r = HighPassFilter.new(sample_rate: sample_rate, cutoff: 20.0)
        @hpf_cutoff = 20.0
      end

      def trigger(text:, gain: 1.0, speed: 1.0, duration: nil, attack: nil, decay: nil, sustain: nil, release: nil, hpf: nil,
voice: nil, rate: nil, pitch: nil)
        @audio_data = @generator.generate(text, voice: voice, rate: rate, pitch: pitch)
        return unless @audio_data

        @position = 0.0
        @playing = true
        @gain = gain
        @speed = speed
        @elapsed_samples = 0
        @released = false
        @hold_duration = duration

        # Amp ADSR
        a, d, s, r = resolve_adsr(attack, decay, sustain, release, default_values: [0.001, 0.001, 1.0, 0.01])
        @amp_envelope.reset
        @amp_envelope.attack = a
        @amp_envelope.decay = d
        @amp_envelope.sustain = s
        @amp_envelope.release = r
        @amp_envelope.trigger

        # HPF
        @hpf_cutoff = hpf if hpf
        @hpf_l.cutoff = @hpf_cutoff
        @hpf_l.reset
        @hpf_r.cutoff = @hpf_cutoff
        @hpf_r.reset
      end

      def stop
        @playing = false
      end

      def playing?
        @playing
      end

      def generate(frame_count)
        return [0.0] * frame_count unless @playing || @released

        output = []

        frame_count.times do |frame_idx|
          if @playing && @position >= @audio_data.length
            if @hold_duration
              @released = true
              @amp_envelope.release_envelope
              @playing = false
            else
              @playing = false
              @released = false
            end
          end

          if @released && @amp_envelope.done?
            @released = false
          end

          if !@playing && !@released
            output << 0.0
            next
          end

          # Read from audio data with speed
          sample_index = (@position * @speed).to_i % @audio_data.length
          left_sample = if sample_index < @audio_data.length
                          @audio_data[sample_index * 2] || 0.0
                        else
                          0.0
                        end
          right_sample = if (sample_index * 2 + 1) < @audio_data.length
                           @audio_data[sample_index * 2 + 1] || 0.0
                         else
                           0.0
                         end

          @position += 1.0

          # Envelope
          env_sample = @amp_envelope.next_sample

          # HPF
          left_filtered = @hpf_l.process(left_sample * env_sample * @gain)
          right_filtered = @hpf_r.process(right_sample * env_sample * @gain)

          # Mix stereo to mono for output
          output << (left_filtered + right_filtered) / 2.0

          @elapsed_samples += 1

          # Check duration
          if @hold_duration && @elapsed_samples >= (@hold_duration * @sample_rate).to_i
            @released = true
            @amp_envelope.release_envelope
            @playing = false
          end
        end

        output
      end

      private

      def resolve_adsr(attack, decay, sustain, release, default_values: [0, 0, 1.0, 0])
        [
          attack || default_values[0],
          decay || default_values[1],
          sustain.nil? ? default_values[2] : sustain,
          release || default_values[3],
        ]
      end
    end
  end
end
