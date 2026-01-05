# frozen_string_literal: true

module Strudel
  module Audio
    class SynthPlayer
      attr_reader :playing

      # A4 = 440Hz, MIDI note 69
      A4_FREQUENCY = 440.0
      A4_MIDI_NOTE = 69

      # Default filter settings
      DEFAULT_LPF_CUTOFF = 20_000.0  # Wide open by default
      DEFAULT_LPF_RESONANCE = 0.0
      DEFAULT_LPF_ENV_AMOUNT = 0.0

      def initialize(waveform = :sine, sample_rate: 44_100, decay: 1.0, gain: 1.0, detune: nil)
        detune_value = detune || Oscillator::DEFAULT_SUPERSAW_DETUNE
        @oscillator = Oscillator.new(waveform, sample_rate: sample_rate, detune: detune_value)
        @sample_rate = sample_rate
        @decay = decay
        @gain = gain
        @playing = false
        @frequency = 440.0
        @elapsed_samples = 0

        # LPF settings
        @lpf_cutoff = DEFAULT_LPF_CUTOFF
        @lpf_resonance = DEFAULT_LPF_RESONANCE
        @lpf_env_amount = DEFAULT_LPF_ENV_AMOUNT
        @lpf_attack = 0.01
        @lpf_decay = 0.1
        @lpf_sustain = 0.5
        @lpf_release = 0.2

        # Initialize filter and envelope
        @filter = LowPassFilter.new(sample_rate: sample_rate, cutoff: @lpf_cutoff, resonance: @lpf_resonance)
        @filter_envelope = FilterEnvelope.new(sample_rate: sample_rate)
      end

      def trigger(frequency: nil, note: nil, gain: nil, detune: nil,
                  lpf: nil, lpq: nil, lpenv: nil, lpa: nil, lpd: nil, lps: nil, lpr: nil)
        @frequency = if note
                       midi_to_frequency(note)
                     elsif frequency
                       frequency
                     else
                       440.0
                     end
        @gain = gain if gain
        @oscillator.detune = detune if detune

        # LPF parameters
        @lpf_cutoff = lpf if lpf
        @lpf_resonance = lpq if lpq
        @lpf_env_amount = lpenv if lpenv
        @lpf_attack = lpa if lpa
        @lpf_decay = lpd if lpd
        @lpf_sustain = lps if lps
        @lpf_release = lpr if lpr

        # Update filter settings
        @filter.cutoff = @lpf_cutoff
        @filter.resonance = @lpf_resonance
        @filter.reset

        # Setup filter envelope
        @filter_envelope.attack = @lpf_attack
        @filter_envelope.decay = @lpf_decay
        @filter_envelope.sustain = @lpf_sustain
        @filter_envelope.release = @lpf_release
        @filter_envelope.amount = @lpf_env_amount
        @filter_envelope.reset
        @filter_envelope.trigger

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

        # Apply filter with envelope modulation
        samples.map!.with_index do |sample, i|
          elapsed_time = (@elapsed_samples + i) / @sample_rate.to_f
          amp_envelope = decay_envelope(elapsed_time)

          if amp_envelope <= 0.001
            @playing = false
            0.0
          else
            # Process filter envelope and update cutoff
            modulated_cutoff = @filter_envelope.process(@lpf_cutoff)
            @filter.cutoff = modulated_cutoff

            # Apply filter
            filtered_sample = @filter.process_sample(sample)

            filtered_sample * amp_envelope * @gain
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
