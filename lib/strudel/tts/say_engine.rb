# frozen_string_literal: true

require "open3"
require_relative "engine"

module Strudel
  module TTS
    class SayEngine < Engine
      def name
        :say
      end

      def available?
        return false unless RUBY_PLATFORM.include?("darwin")

        _stdout, _stderr, status = Open3.capture3("which", "say")
        status.success?
      rescue StandardError
        false
      end

      def generate(text:, voice:, rate:, output_path:)
        if voice
          validate_voice!(voice.to_s)
        end

        args = ["say", "-o", output_path, "--file-format=WAVE", "--data-format=LEI16@44100"]
        args.push("-v", voice.to_s) if voice
        args.push("-r", rate.to_s) if rate
        args << text.to_s

        _stdout, stderr, status = Open3.capture3(*args)
        unless status.success?
          raise TTSGenerationError, "say exited #{status.exitstatus}: #{stderr.strip}"
        end
        unless File.exist?(output_path) && File.size(output_path) > 0
          raise TTSGenerationError, "say produced no output for text=#{text.inspect}"
        end
      end

      private

      def validate_voice!(voice_name)
        stdout, _stderr, status = Open3.capture3("say", "-v", "?")
        return unless status.success?

        available_voices = stdout.lines.map { |line| line.split(/\s+/).first }
        unless available_voices.any? { |v| v.casecmp(voice_name).zero? }
          raise TTSGenerationError, "voice not available: #{voice_name.inspect}"
        end
      end
    end
  end
end
