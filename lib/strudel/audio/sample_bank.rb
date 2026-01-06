# frozen_string_literal: true

require "wavefile"

module Strudel
  module Audio
    class SampleBank
      def initialize(samples_path = nil)
        @samples_path = samples_path || default_samples_path
        @cache = {}
      end

      # Get sample (with caching)
      def get(name, n = 0)
        key = "#{name}:#{n}"
        @cache[key] ||= load_sample(name, n)
      end

      private

      def default_samples_path
        File.expand_path("../../../../samples", __FILE__)
      end

      def sample_path(name, n)
        File.join(@samples_path, name, "#{n}.wav")
      end

      def load_sample(name, n)
        path = sample_path(name, n)

        unless File.exist?(path)
          warn "Sample not found: #{path}"
          return SampleData.silent
        end

        begin
          reader = WaveFile::Reader.new(path)
          format = reader.format
          buffer = reader.read(reader.total_sample_frames)
          reader.close

          # Keep (up to) stereo channels (Strudel-like)
          channels =
            if format.channels == 1
              [buffer.samples]
            else
              # WaveFile returns frames like [L, R, ...]
              channel_count = [format.channels, 2].min
              chans = Array.new(channel_count) { [] }
              buffer.samples.each do |frame|
                channel_count.times do |i|
                  chans[i] << frame[i]
                end
              end
              chans
            end

          # Normalize to Float32 per channel
          normalized_channels = channels.map { |ch| normalize_samples(ch, format.bits_per_sample) }

          SampleData.new(normalized_channels, format.sample_rate)
        rescue StandardError => e
          warn "Failed to load sample #{path}: #{e.message}"
          SampleData.silent
        end
      end

      def normalize_samples(samples, bits_per_sample)
        max_value = (2**(bits_per_sample - 1)).to_f
        samples.map { |s| s / max_value }
      end
    end

    # Class to hold sample data
    class SampleData
      attr_reader :channels, :sample_rate

      def initialize(channels, sample_rate)
        @channels = channels
        @sample_rate = sample_rate
      end

      def channel_count
        @channels.length
      end

      def length
        return 0 if empty?

        @channels.map(&:length).min
      end

      def empty?
        @channels.empty? || @channels.all?(&:empty?)
      end

      def self.silent
        new([], 44_100)
      end
    end
  end
end
