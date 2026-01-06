# frozen_string_literal: true

module Strudel
  module Audio
    # Simple ADSR envelope (linear segments), driven per-sample.
    #
    # This is used to approximate Strudel/superdough's gain envelope:
    # the envelope is held for the event duration, then released.
    class ADSREnvelope
      attr_accessor :attack, :decay, :sustain, :release

      def initialize(sample_rate: 44_100, attack: 0.001, decay: 0.05, sustain: 0.6, release: 0.01)
        @sample_rate = sample_rate
        @attack = attack
        @decay = decay
        @sustain = sustain
        @release = release
        reset
      end

      def trigger
        @stage = :attack
        @samples_in_stage = 0
      end

      def release_note
        start_level = @level
        @stage = :release
        @samples_in_stage = 0
        @release_start_level = start_level
      end

      def process
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
          @level = (@release_start_level || 0.0) * (1.0 - progress)
          if @samples_in_stage >= release_samples
            @stage = :idle
            @level = 0.0
          end
        else
          @level = 0.0
        end

        @samples_in_stage += 1
        @level
      end

      def active?
        @stage != :idle
      end

      def reset
        @stage = :idle
        @level = 0.0
        @samples_in_stage = 0
        @release_start_level = 0.0
      end
    end
  end
end
