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
      DEFAULT_LPF_RESONANCE = 1.0
      DEFAULT_LPF_ENV = 0.0

      # Default gain envelope (Strudel/superdough defaults for synth waveforms)
      DEFAULT_AMP_ATTACK = 0.001
      DEFAULT_AMP_DECAY = 0.05
      DEFAULT_AMP_SUSTAIN = 0.6
      DEFAULT_AMP_RELEASE = 0.01

      DEFAULT_AMP_LEVEL = 0.3

      def initialize(waveform = :sine, sample_rate: 44_100, decay: 1.0, gain: 1.0, detune: nil, unison: nil, spread: nil)
        detune_value = detune || Oscillator::DEFAULT_SUPERSAW_DETUNE
        voices = unison&.to_i if waveform == :supersaw
        @spread = spread
        @oscillator = Oscillator.new(waveform, sample_rate: sample_rate, detune: detune_value, voices: voices)
        @sample_rate = sample_rate
        @decay = decay
        @gain = gain
        @playing = false
        @frequency = 440.0
        @elapsed_samples = 0
        @released = false
        @hold_duration = nil
        @fmi = nil
        @fmh = 1.0
        @fmwave = :sine
        @fm_oscillator = nil

        # LPF settings
        @lpf_cutoff = DEFAULT_LPF_CUTOFF
        @lpf_resonance = DEFAULT_LPF_RESONANCE
        @lpf_env = DEFAULT_LPF_ENV
        # Strudel(superdough) filter envelope defaults: [0.005, 0.14, 0, 0.1]
        @lpf_attack = 0.005
        @lpf_decay = 0.14
        @lpf_sustain = 0.0
        @lpf_release = 0.1

        # Initialize filter and envelope
        @filter = LowPassFilter.new(sample_rate: sample_rate, cutoff: @lpf_cutoff, resonance: @lpf_resonance)
        @filter_envelope = FilterEnvelope.new(sample_rate: sample_rate)
        @amp_envelope = ADSREnvelope.new(
          sample_rate: sample_rate,
          attack: DEFAULT_AMP_ATTACK,
          decay: DEFAULT_AMP_DECAY,
          sustain: DEFAULT_AMP_SUSTAIN,
          release: DEFAULT_AMP_RELEASE
        )
      end

      def trigger(frequency: nil, note: nil, gain: nil, detune: nil,
                  duration: nil,
                  attack: nil, decay: nil, sustain: nil, release: nil,
                  fmi: nil, fmh: nil, fmwave: nil,
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
        @hold_duration = duration
        @released = false

        @fmi = fmi&.to_f
        @fmh = (fmh || 1.0).to_f
        @fmwave = (fmwave || :sine).to_s.downcase.to_sym
        @fm_oscillator = Oscillator.new(@fmwave, sample_rate: @sample_rate) if @fmi && @fmi != 0.0

        # LPF parameters
        @lpf_cutoff = lpf if lpf
        @lpf_resonance = lpq if lpq
        @lpf_env = lpenv if lpenv
        @lpf_attack = lpa if lpa
        @lpf_decay = lpd if lpd
        @lpf_sustain = lps if lps
        @lpf_release = lpr if lpr

        # Update filter settings
        @filter.cutoff = @lpf_cutoff
        @filter.resonance = @lpf_resonance
        @filter.reset

        # Setup filter envelope
        @filter_envelope.configure(
          base_frequency: @lpf_cutoff,
          env: @lpf_env,
          anchor: 0.0,
          attack: @lpf_attack,
          decay: @lpf_decay,
          sustain: @lpf_sustain,
          release: @lpf_release
        )
        @filter_envelope.reset
        @filter_envelope.trigger

        # Setup gain envelope
        @amp_envelope.reset
        defaults = [DEFAULT_AMP_ATTACK, DEFAULT_AMP_DECAY, DEFAULT_AMP_SUSTAIN, DEFAULT_AMP_RELEASE]
        a, d, s, r = resolve_adsr(attack, decay, sustain, release, default_values: defaults)
        @amp_envelope.attack = a
        @amp_envelope.decay = d
        @amp_envelope.sustain = s
        @amp_envelope.release = r
        @amp_envelope.trigger

        @elapsed_samples = 0
        @oscillator.reset
        @fm_oscillator&.reset
        @playing = true
      end

      def stop
        @playing = false
      end

      def playing?
        @playing
      end

      def generate(frame_count)
        silence = [Array.new(frame_count, 0.0), Array.new(frame_count, 0.0)]
        return silence unless @playing

        samples =
          if @fmi && @fmi != 0.0 && @fm_oscillator
            Array.new(frame_count) do
              base_freq = @frequency
              modfreq = base_freq * @fmh
              mod = @fm_oscillator.step(modfreq)
              freq = base_freq + mod * modfreq * @fmi
              @oscillator.step([freq, 0.0].max)
            end
          else
            @oscillator.generate(frequency: @frequency, frame_count: frame_count)
          end

        # Apply filter + envelopes
        samples.map!.with_index do |sample, i|
          elapsed_time = (@elapsed_samples + i) / @sample_rate.to_f
          if @hold_duration && !@released && elapsed_time >= @hold_duration
            @released = true
            @amp_envelope.release_note
            @filter_envelope.release_note
          end

          amp_envelope = @hold_duration ? @amp_envelope.process : decay_envelope(elapsed_time)

          if @hold_duration
            if @released && !@amp_envelope.active?
              @playing = false
              0.0
            else
              # Process filter envelope and update cutoff
              modulated_cutoff = @filter_envelope.process
              @filter.cutoff = modulated_cutoff

              # Apply filter
              filtered_sample = @filter.process_sample(sample)

              filtered_sample * amp_envelope * @gain * DEFAULT_AMP_LEVEL
            end
          elsif amp_envelope <= 0.001
            @playing = false
            0.0
          else
            # Process filter envelope and update cutoff
            modulated_cutoff = @filter_envelope.process
            @filter.cutoff = modulated_cutoff

            # Apply filter
            filtered_sample = @filter.process_sample(sample)

            filtered_sample * amp_envelope * @gain * DEFAULT_AMP_LEVEL
          end
        end

        @elapsed_samples += frame_count
        [samples.dup, samples.dup]
      end

      private

      def midi_to_frequency(note)
        A4_FREQUENCY * (2.0**((note - A4_MIDI_NOTE) / 12.0))
      end

      def decay_envelope(time)
        # Simple exponential decay
        Math.exp(-time / @decay)
      end

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
