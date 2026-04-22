# frozen_string_literal: true

module Strudel
  module Audio
    class TTSGenerator
      def initialize(say_engine: nil)
        @say_engine = say_engine || SayEngine.new
        @cache = {}
      end

      def generate(text, voice: nil, rate: nil, pitch: nil)
        cache_key = [text, voice, rate, pitch].hash
        return @cache[cache_key] if @cache.key?(cache_key)

        audio = @say_engine.speak(text, voice: voice, rate: rate, pitch: pitch)
        @cache[cache_key] = audio if audio
        audio
      end

      def clear_cache
        @cache.clear
      end
    end
  end
end
