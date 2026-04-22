# frozen_string_literal: true

require "digest"
require "fileutils"
require_relative "engine"

module Strudel
  module TTS
    # Resolves TTS requests by:
    # 1. Picking the first available engine
    # 2. Looking up a deterministic cache path keyed by (engine, text, voice, rate)
    # 3. Invoking the engine only on cache miss
    class Generator
      DEFAULT_CACHE_DIR = File.expand_path("~/.cache/strudel-rb/say")

      def initialize(cache_dir: DEFAULT_CACHE_DIR, engines: [])
        @cache_dir = cache_dir
        @engines = engines
      end

      def generate(text, engine: nil, voice: nil, rate: nil)
        selected = select_engine(engine)
        FileUtils.mkdir_p(@cache_dir)
        path = cache_path(selected.name, text, voice, rate)
        return path if File.exist?(path) && File.size(path) > 0

        selected.generate(text: text, voice: voice, rate: rate, output_path: path)
        unless File.exist?(path) && File.size(path) > 0
          raise TTSGenerationError, "#{selected.name} produced no output for text=#{text.inspect}"
        end
        path
      end

      private

      def select_engine(requested_name)
        candidates = requested_name ? @engines.select { |e| e.name == requested_name } : @engines
        found = candidates.find(&:available?)
        return found if found

        raise NoAvailableEngineError,
              "No available TTS engine (requested=#{requested_name.inspect}, engines=#{@engines.map(&:name).inspect})"
      end

      def cache_path(engine_name, text, voice, rate)
        key = [engine_name, text, voice, rate].map(&:to_s).join("\x1f")
        hash = Digest::SHA256.hexdigest(key)
        File.join(@cache_dir, "#{hash}.wav")
      end
    end
  end
end
