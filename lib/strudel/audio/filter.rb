# frozen_string_literal: true

module Strudel
  module Audio
    # Simple one-pole low-pass filter (IIR)
    class LowPassFilter
      attr_reader :cutoff, :resonance

      # Smoothing factor for cutoff changes (prevents clicks)
      CUTOFF_SMOOTHING = 0.99

      def initialize(sample_rate: 44_100, cutoff: 20_000.0, resonance: 0.0)
        @sample_rate = sample_rate
        @target_cutoff = cutoff.clamp(20.0, 20_000.0)
        @cutoff = @target_cutoff
        @resonance = resonance.clamp(0.0, 1.0)
        @y1 = 0.0  # Previous output (for feedback)
        @y2 = 0.0  # Two samples ago
        @x1 = 0.0  # Previous input
        @x2 = 0.0  # Two samples ago
        @coefficients_dirty = true
        update_coefficients
      end

      def cutoff=(value)
        @target_cutoff = value.clamp(20.0, 20_000.0)
      end

      def resonance=(value)
        new_resonance = value.clamp(0.0, 1.0)
        if new_resonance != @resonance
          @resonance = new_resonance
          @coefficients_dirty = true
        end
      end

      def process(samples)
        samples.map do |sample|
          process_sample(sample)
        end
      end

      def process_sample(input)
        # Smooth cutoff changes to prevent clicks
        if (@cutoff - @target_cutoff).abs > 1.0
          @cutoff = @cutoff * CUTOFF_SMOOTHING + @target_cutoff * (1.0 - CUTOFF_SMOOTHING)
          @coefficients_dirty = true
        elsif @cutoff != @target_cutoff
          @cutoff = @target_cutoff
          @coefficients_dirty = true
        end

        # Update coefficients only when needed
        update_coefficients if @coefficients_dirty

        # Biquad low-pass filter
        output = @b0 * input + @b1 * @x1 + @b2 * @x2 - @a1 * @y1 - @a2 * @y2

        # Shift samples
        @x2 = @x1
        @x1 = input
        @y2 = @y1
        @y1 = output

        # Soft clip to prevent blow-up with high resonance
        output.clamp(-2.0, 2.0)
      end

      def reset
        @y1 = 0.0
        @y2 = 0.0
        @x1 = 0.0
        @x2 = 0.0
      end

      private

      def update_coefficients
        @coefficients_dirty = false

        # Clamp cutoff to valid range
        freq = @cutoff.clamp(20.0, @sample_rate * 0.45)

        # Calculate filter coefficients (biquad low-pass)
        omega = 2.0 * Math::PI * freq / @sample_rate
        sin_omega = Math.sin(omega)
        cos_omega = Math.cos(omega)

        # Q factor from resonance (0-1 mapped to 0.5-10, reduced max for stability)
        q = 0.5 + @resonance * 9.5
        alpha = sin_omega / (2.0 * q)

        # Low-pass coefficients
        b0 = (1.0 - cos_omega) / 2.0
        b1 = 1.0 - cos_omega
        b2 = (1.0 - cos_omega) / 2.0
        a0 = 1.0 + alpha
        a1 = -2.0 * cos_omega
        a2 = 1.0 - alpha

        # Normalize
        @b0 = b0 / a0
        @b1 = b1 / a0
        @b2 = b2 / a0
        @a1 = a1 / a0
        @a2 = a2 / a0
      end
    end

    # ADSR Envelope for filter modulation
    class FilterEnvelope
      attr_accessor :attack, :decay, :sustain, :release, :amount

      def initialize(sample_rate: 44_100)
        @sample_rate = sample_rate
        @attack = 0.01   # Attack time in seconds
        @decay = 0.1     # Decay time in seconds
        @sustain = 0.5   # Sustain level (0-1)
        @release = 0.2   # Release time in seconds
        @amount = 1.0    # Envelope amount (how much it affects the filter)
        @stage = :idle
        @level = 0.0
        @samples_in_stage = 0
      end

      def trigger
        @stage = :attack
        @samples_in_stage = 0
      end

      def release_note
        @stage = :release
        @samples_in_stage = 0
        @release_start_level = @level
      end

      def process(base_cutoff)
        case @stage
        when :attack
          attack_samples = (@attack * @sample_rate).to_i.clamp(1, 1_000_000)
          @level = @samples_in_stage.to_f / attack_samples
          if @samples_in_stage >= attack_samples
            @stage = :decay
            @samples_in_stage = 0
            @level = 1.0
          end
        when :decay
          decay_samples = (@decay * @sample_rate).to_i.clamp(1, 1_000_000)
          progress = @samples_in_stage.to_f / decay_samples
          @level = 1.0 - (1.0 - @sustain) * progress
          if @samples_in_stage >= decay_samples
            @stage = :sustain
            @level = @sustain
          end
        when :sustain
          @level = @sustain
        when :release
          release_samples = (@release * @sample_rate).to_i.clamp(1, 1_000_000)
          progress = @samples_in_stage.to_f / release_samples
          @level = @release_start_level * (1.0 - progress)
          if @samples_in_stage >= release_samples
            @stage = :idle
            @level = 0.0
          end
        else
          @level = 0.0
        end

        @samples_in_stage += 1

        # Calculate modulated cutoff
        # amount controls how much the envelope opens the filter
        modulated_cutoff = base_cutoff + (@amount * @level)
        modulated_cutoff.clamp(20.0, 20_000.0)
      end

      def active?
        @stage != :idle
      end

      def reset
        @stage = :idle
        @level = 0.0
        @samples_in_stage = 0
      end
    end
  end
end
