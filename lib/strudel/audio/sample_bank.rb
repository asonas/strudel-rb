# frozen_string_literal: true

require "json"
require "wavefile"

module Strudel
  module Audio
    class SampleBank
      def initialize(samples_path = nil)
        @samples_path = samples_path || default_samples_path
        @cache = {}
        @pitch_cache = {}
        @remote_sources = []
        @path_cache = {}
      end

      def add_remote_source(source)
        @remote_sources << source
      end

      # Get sample (with caching)
      def get(name, n = 0)
        key = "#{name}:#{n}"
        @cache[key] ||= load_sample(name, n)
      end

      # Get pitch mapping for a sample set
      # Returns {0 => 60, 1 => 72} or nil if no pitch.json
      def pitch_map(name)
        return @pitch_cache[name] if @pitch_cache.key?(name)

        path = File.join(@samples_path, name, "pitch.json")
        unless File.exist?(path)
          remote_pitch = find_remote_pitch_json(name)
          path = remote_pitch if remote_pitch
        end

        @pitch_cache[name] = if File.exist?(path)
                               raw = JSON.parse(File.read(path))
                               raw.each_with_object({}) { |(k, v), h| h[k.to_i] = v.to_i }
                             end
      end

      # Get sample with pitch-shift speed for a target MIDI note
      # Returns [sample_data, speed_ratio]
      def get_pitched(name, target_note)
        mapping = pitch_map(name)

        unless mapping
          return [get(name, 0), 1.0]
        end

        closest_n = mapping.min_by { |_n, base_note| (base_note - target_note).abs }.first
        base_note = mapping[closest_n]
        speed = 2.0**((target_note - base_note) / 12.0)

        [get(name, closest_n), speed]
      end

      def load_path(path)
        return SampleData.silent unless File.exist?(path)

        @path_cache[path] ||= load_wav_file(path)
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
          remote_path = find_remote(name, n)
          if remote_path
            path = remote_path
          else
            warn "Sample not found: #{path}"
            return SampleData.silent
          end
        end

        load_wav_file(path)
      end

      def load_wav_file(path)
        reader = WaveFile::Reader.new(path)
        format = reader.format
        buffer = reader.read(reader.total_sample_frames)
        reader.close

        channels =
          if format.channels == 1
            [buffer.samples]
          else
            channel_count = [format.channels, 2].min
            chans = Array.new(channel_count) { [] }
            buffer.samples.each do |frame|
              channel_count.times { |i| chans[i] << frame[i] }
            end
            chans
          end

        normalized_channels = channels.map { |ch| normalize_samples(ch, format.bits_per_sample) }
        SampleData.new(normalized_channels, format.sample_rate)
      rescue StandardError => e
        warn "Failed to load sample #{path}: #{e.message}"
        SampleData.silent
      end

      def find_remote(name, n)
        @remote_sources.each do |source|
          path = source.get_path(name, n)
          return path if path && File.exist?(path)
        end
        nil
      end

      def find_remote_pitch_json(name)
        @remote_sources.each do |source|
          path = source.pitch_json_path(name)
          return path if path
        end
        nil
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

      def duration_seconds
        return 0.0 if empty? || @sample_rate.nil? || @sample_rate.zero?

        length.to_f / @sample_rate.to_f
      end

      def self.silent
        new([], 44_100)
      end
    end
  end
end
