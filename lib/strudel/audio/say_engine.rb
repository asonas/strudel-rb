# frozen_string_literal: true

require 'open3'

module Strudel
  module Audio
    class SayEngine
      DEFAULT_VOICE = 'en_US'
      DEFAULT_RATE = 150
      DEFAULT_PITCH = 50

      def initialize(voice: DEFAULT_VOICE, rate: DEFAULT_RATE, pitch: DEFAULT_PITCH)
        @voice = voice
        @rate = rate
        @pitch = pitch
      end

      def speak(text, rate: nil, pitch: nil, voice: nil)
        actual_rate = rate || @rate
        actual_pitch = pitch || @pitch
        actual_voice = voice || @voice

        audio_data = synthesize_audio(text, actual_voice, actual_rate, actual_pitch)
        audio_data
      end

      private

      def synthesize_audio(text, voice, rate, pitch)
        # Use macOS say command to generate audio
        # On Linux/Windows, this would need alternative TTS engines
        tmpfile = "/tmp/tts_#{Time.now.to_i}_#{rand(10000)}.aiff"

        begin
          cmd = ['say', '-v', voice, '-r', rate.to_s, '-o', tmpfile, text]
          stdout, stderr, status = Open3.capture3(*cmd)

          unless status.success?
            warn "TTS synthesis failed: #{stderr}"
            return nil
          end

          # Convert AIFF to raw PCM data (44100 Hz, 16-bit, stereo)
          audio_file = WaveFile::Reader.new(tmpfile, WaveFile::Format.new(:pcm, :stereo, 44_100, 16))
          samples = audio_file.read.samples

          # Flatten stereo samples to a single array
          flattened = samples.flatten

          SynthesizedAudio.new(flattened, 44_100, 2)
        ensure
          File.delete(tmpfile) if File.exist?(tmpfile)
        end
      end
    end

    class SynthesizedAudio
      attr_reader :sample_rate, :channels

      def initialize(samples, sample_rate, channels = 2)
        @samples = samples
        @sample_rate = sample_rate
        @channels = channels
        @position = 0
      end

      def read(count)
        return [] if @position >= @samples.length

        end_position = [@position + count, @samples.length].min
        chunk = @samples[@position...end_position]
        @position = end_position
        chunk
      end

      def length
        @samples.length
      end

      def [](index)
        @samples[index]
      end

      def duration_seconds
        @samples.length.to_f / @sample_rate / @channels
      end

      def reset
        @position = 0
      end
    end
  end
end
