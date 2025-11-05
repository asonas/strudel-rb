# frozen_string_literal: true

module Strudel
  module Scheduler
    class Cyclist
      attr_accessor :cps, :pattern
      attr_reader :sample_rate

      DEFAULT_CPS = 0.5 # cycles per second (1 cycle = 2 seconds)
      DEFAULT_SAMPLE_RATE = 44_100
      SYNTH_WAVEFORMS = %w[sine sawtooth square triangle].freeze

      def initialize(sample_rate: DEFAULT_SAMPLE_RATE, cps: DEFAULT_CPS, samples_path: nil)
        @sample_rate = sample_rate
        @cps = cps
        @pattern = nil
        @sample_bank = Audio::SampleBank.new(samples_path)
        @active_players = []
        @current_cycle = Fraction.new(0)
        @mutex = Mutex.new
      end

      # Set the pattern
      def set_pattern(pattern)
        @mutex.synchronize do
          @pattern = pattern
        end
      end

      # Generate audio frames (called by VCA)
      def generate(frame_count)
        @mutex.synchronize do
          # Convert frame count to cycle count
          frames_per_cycle = @sample_rate / @cps
          duration_in_cycles = Fraction.new(Rational(frame_count, frames_per_cycle.to_i))

          end_cycle = @current_cycle + duration_in_cycles

          # Query pattern to get Haps
          if @pattern
            begin
              haps = @pattern.query_arc(@current_cycle.value, end_cycle.value)

              # Trigger sounds for Haps with onset
              haps.select(&:has_onset?).each do |hap|
                trigger_sound(hap)
              end
            rescue StandardError => e
              warn "Error querying pattern: #{e.message}"
            end
          end

          # Generate and mix samples from active players
          samples = mix_players(frame_count)

          # Remove finished players
          @active_players.reject! { |p| !p.playing? }

          @current_cycle = end_cycle
          samples
        end
      end

      # Reset cycle position
      def reset
        @mutex.synchronize do
          @current_cycle = Fraction.new(0)
          @active_players.clear
        end
      end

      private

      def trigger_sound(hap)
        value = hap.value

        # Extract sound name and sample number from value
        sound_name, sample_n = extract_sound_info(value)
        return unless sound_name

        gain = extract_gain(value)

        # For synth sounds
        if SYNTH_WAVEFORMS.include?(sound_name)
          player = Audio::SynthPlayer.new(
            sound_name.to_sym,
            sample_rate: @sample_rate,
            gain: gain
          )
          note = extract_note(value)
          player.trigger(note: note)
          @active_players << player
          return
        end

        # For sample sounds
        sample_data = @sample_bank.get(sound_name, sample_n)
        return if sample_data.empty?

        speed = extract_speed(value)
        player = Audio::SamplePlayer.new(sample_data, @sample_rate)
        player.trigger(gain: gain, speed: speed)
        @active_players << player
      end

      def extract_sound_info(value)
        case value
        when String
          [value, 0]
        when Hash
          name = value[:s] || value[:sound]
          n = value[:n] || 0
          [name, n]
        else
          [nil, 0]
        end
      end

      def extract_gain(value)
        return 1.0 unless value.is_a?(Hash)

        value[:gain] || value[:velocity]&./(127.0) || 1.0
      end

      def extract_note(value)
        return 60 unless value.is_a?(Hash) # Default: C4

        value[:note] || value[:n] || 60
      end

      def extract_speed(value)
        return 1.0 unless value.is_a?(Hash)

        value[:speed] || 1.0
      end

      def mix_players(frame_count)
        return Array.new(frame_count, 0.0) if @active_players.empty?

        # Get samples from each player
        player_outputs = @active_players.map { |p| p.generate(frame_count) }

        # Mix
        mixed = Array.new(frame_count, 0.0)
        player_outputs.each do |output|
          frame_count.times do |i|
            mixed[i] += output[i]
          end
        end

        # Gain adjustment (based on number of simultaneous sounds)
        active_count = @active_players.count(&:playing?)
        if active_count > 1
          gain = 1.0 / Math.sqrt(active_count)
          mixed.map! { |s| s * gain }
        end

        mixed
      end
    end
  end
end
