module Strudel
  module TTS
    # Test-only TTS engine that copies a fixture WAV file to the output path
    class FakeEngine
      def initialize(output_path: nil)
        @output_path = output_path || File.expand_path('../fixtures/tts/test_voice.wav', __dir__)
        @fixture_path = File.expand_path('../fixtures/tts/test_voice.wav', __dir__)
      end

      def synthesize(text, output_path: nil)
        target_path = output_path || @output_path
        ensure_fixture_exists
        FileUtils.cp(@fixture_path, target_path)
        target_path
      end

      private

      def ensure_fixture_exists
        unless File.exist?(@fixture_path)
          raise "Fixture WAV file not found at #{@fixture_path}"
        end
      end
    end
  end
end
