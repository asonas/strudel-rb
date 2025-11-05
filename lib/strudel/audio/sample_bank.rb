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

      # Check if sample exists
      def exists?(name, n = 0)
        path = sample_path(name, n)
        File.exist?(path)
      end

      # List available sample names
      def available_samples
        return [] unless Dir.exist?(@samples_path)

        Dir.children(@samples_path)
           .select { |f| File.directory?(File.join(@samples_path, f)) }
           .sort
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

          # Convert to mono (use left channel only for stereo)
          samples = if format.channels == 1
                      buffer.samples
                    else
                      buffer.samples.map { |frame| frame[0] }
                    end

          # Normalize to Float32
          normalized = normalize_samples(samples, format.bits_per_sample)

          SampleData.new(normalized, format.sample_rate)
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
      attr_reader :samples, :sample_rate

      def initialize(samples, sample_rate)
        @samples = samples
        @sample_rate = sample_rate
      end

      def length
        @samples.length
      end

      def empty?
        @samples.empty?
      end

      def self.silent
        new([], 44_100)
      end
    end
  end
end
