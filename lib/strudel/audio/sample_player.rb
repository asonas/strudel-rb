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
        @elapsed_samples = 0
        @released = false
        @hold_duration = nil
        @amp_envelope = ADSREnvelope.new(sample_rate: target_sample_rate)
        @hpf_l = HighPassFilter.new(sample_rate: target_sample_rate, cutoff: 20.0)
        @hpf_r = HighPassFilter.new(sample_rate: target_sample_rate, cutoff: 20.0)
        @hpf_cutoff = 20.0

        # Base sample rate conversion ratio
        @base_rate_ratio = sample_data.sample_rate.to_f / target_sample_rate
      end

      # Start playback
      def trigger(gain: 1.0, speed: 1.0, duration: nil, attack: nil, decay: nil,
                  sustain: nil, release: nil, hpf: nil, begin_frac: nil, end_frac: nil)
        src_len = [@sample_data.channels[0]&.length || 0,
                   @sample_data.channels[1]&.length || (@sample_data.channels[0]&.length || 0),].min
        @position = begin_frac ? (src_len * begin_frac.to_f) : 0.0
        @end_position = end_frac ? (src_len * end_frac.to_f) : nil
        @playing = true
        @gain = gain
        @speed = speed
        @elapsed_samples = 0
        @released = false
        @hold_duration = duration

        # Amp ADSR (Strudel-like defaults)
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
        silence = [Array.new(frame_count, 0.0), Array.new(frame_count, 0.0)]
        return silence unless @playing
        return silence if @sample_data.empty?

        channels = @sample_data.channels
        left_src = channels[0] || []
        right_src = channels[1] || left_src # mono -> stereo
        src_len = [left_src.length, right_src.length].min

        out_l = Array.new(frame_count, 0.0)
        out_r = Array.new(frame_count, 0.0)

        # Rate ratio considering speed
        rate_ratio = @base_rate_ratio * @speed.abs

        frame_count.times do |i|
          elapsed_time = (@elapsed_samples + i) / @target_sample_rate.to_f
          if @hold_duration && !@released && elapsed_time >= @hold_duration
            @released = true
            @amp_envelope.release_note
          end

          idx = @position.to_i

          if idx >= src_len || idx < 0 || (@end_position && idx >= @end_position)
            @playing = false
            break
          end

          # Get sample value using linear interpolation
          frac = @position - idx
          current_l = left_src[idx] || 0.0
          next_l = left_src[idx + 1] || current_l
          current_r = right_src[idx] || 0.0
          next_r = right_src[idx + 1] || current_r
          amp = @hold_duration ? @amp_envelope.process : 1.0
          sample_l = (current_l + (next_l - current_l) * frac)
          sample_r = (current_r + (next_r - current_r) * frac)
          # Apply HPF if cutoff is above minimum
          if @hpf_cutoff > 20.0
            sample_l = @hpf_l.process_sample(sample_l)
            sample_r = @hpf_r.process_sample(sample_r)
          end
          out_l[i] = sample_l * @gain * amp
          out_r[i] = sample_r * @gain * amp

          # For reverse playback (negative speed), move in reverse direction
          @position += @speed >= 0 ? rate_ratio : -rate_ratio
        end

        @elapsed_samples += frame_count
        @playing = false if @hold_duration && @released && !@amp_envelope.active?

        [out_l, out_r]
      end

      private

      def resolve_adsr(attack, decay, sustain, release, default_values:)
        envmin = 0.001
        release_min = 0.01
        envmax = 1.0

        if [attack, decay, sustain, release].all?(&:nil?)
          return default_values
        end

        sustain_value =
          if sustain
            sustain.to_f
          elsif (!attack.nil? && decay.nil?) || (attack.nil? && decay.nil?)
            envmax
          else
            envmin
          end

        [
          [attack.to_f, envmin].max,
          [decay.to_f, envmin].max,
          sustain_value.clamp(0.0, envmax),
          [release.to_f, release_min].max,
        ]
      end
    end
  end
end
