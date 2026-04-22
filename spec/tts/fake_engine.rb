# frozen_string_literal: true

require "fileutils"

module Strudel
  module TTS
    # Test-only engine: copies a fixture WAV to output_path.
    # Tracks invocation count so tests can assert caching behavior.
    class FakeEngine < Engine
      FIXTURE_WAV = File.expand_path("../fixtures/tts/test_voice.wav", __dir__)

      attr_reader :call_count
      attr_accessor :available

      def initialize(available: true)
        @call_count = 0
        @available = available
        @last_args = nil
      end

      attr_reader :last_args

      def name
        :fake
      end

      def available?
        @available
      end

      def generate(text:, voice:, rate:, output_path:)
        @call_count += 1
        @last_args = { text: text, voice: voice, rate: rate, output_path: output_path }
        FileUtils.cp(FIXTURE_WAV, output_path)
      end
    end
  end
end
