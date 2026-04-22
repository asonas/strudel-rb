# frozen_string_literal: true

module Strudel
  module TTS
    class Error < StandardError; end
    class TTSGenerationError < Error; end
    class NoAvailableEngineError < Error; end

    # Abstract base class for TTS engines.
    # Subclasses must implement: #name, #available?, #generate(text:, voice:, rate:, output_path:)
    class Engine
      def name
        raise NotImplementedError
      end

      def available?
        raise NotImplementedError
      end

      def generate(text:, voice:, rate:, output_path:)
        raise NotImplementedError
      end
    end
  end
end
