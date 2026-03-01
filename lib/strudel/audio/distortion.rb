# frozen_string_literal: true

module Strudel
  module Audio
    class Distortion
      attr_accessor :amount, :post_gain
      attr_reader :type

      TYPES = %i[sinefold fold diode soft hard].freeze

      def initialize(amount: 0.0, type: :sinefold, post_gain: 1.0)
        @amount = amount.to_f
        @type = TYPES.include?(type.to_sym) ? type.to_sym : :sinefold
        @post_gain = post_gain.to_f
      end

      def type=(value)
        @type = TYPES.include?(value.to_sym) ? value.to_sym : :sinefold
      end

      def process(samples)
        samples.map { |s| process_sample(s) }
      end

      def process_sample(input)
        return input * @post_gain if @amount <= 0.0

        output = case @type
                 when :sinefold
                   sinefold(input)
                 when :fold
                   fold(input)
                 when :diode
                   diode(input)
                 when :soft
                   soft_clip(input)
                 when :hard
                   hard_clip(input)
                 else
                   sinefold(input)
                 end

        output * @post_gain
      end

      private

      # Sine-based wavefolder: maps the amplified signal through sin()
      def sinefold(input)
        Math.sin(input * @amount * Math::PI)
      end

      # Triangle wavefolder: reflects signal at +/-1 boundaries
      def fold(input)
        x = input * @amount
        # Fold the signal: repeatedly reflect at -1 and +1
        x = x % 4.0 if x.abs > 2.0
        if x > 1.0
          2.0 - x
        elsif x < -1.0
          -2.0 - x
        else
          x
        end
      end

      # Half-wave rectifier (diode): only passes positive signal
      def diode(input)
        x = input * @amount
        [x, 0.0].max.clamp(0.0, 1.0)
      end

      # Soft clipping using tanh
      def soft_clip(input)
        Math.tanh(input * @amount)
      end

      # Hard clipping at +/-1
      def hard_clip(input)
        (input * @amount).clamp(-1.0, 1.0)
      end
    end
  end
end
