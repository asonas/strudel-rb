# frozen_string_literal: true

module Strudel
  module Live
    class Session
      def initialize(samples_path: nil, cps: 0.5)
        @samples_path = samples_path
        @cps = cps
        @evaluator = PatternEvaluator.new
        @watcher = nil
        @runner = nil
        @current_pattern = nil
      end

      def load_pattern(path)
        @evaluator.evaluate_file(path)
      rescue SyntaxError => e
        warn "[#{timestamp}] Syntax error: #{e.message}"
        nil
      rescue RuntimeError => e
        warn "[#{timestamp}] Parse error: #{e.message}"
        nil
      rescue StandardError => e
        warn "[#{timestamp}] Error: #{e.class}: #{e.message}"
        nil
      end

      def start(path)
        @path = File.expand_path(path)

        # 初回読み込み
        pattern = load_pattern(@path)
        if pattern
          setup_runner
          @runner.play(pattern)
          @current_pattern = pattern
          puts "[#{timestamp}] Pattern loaded: #{@path}"
        end

        # ファイル監視開始
        @watcher = FileWatcher.new(@path)
        @watcher.on_change { reload_pattern }
        @watcher.start

        puts "Watching: #{@path}"
        puts "Press Ctrl+C to stop"
      end

      def stop
        @watcher&.stop
        @runner&.cleanup
      end

      private

      def setup_runner
        return if @runner

        @runner = Runner.new(samples_path: @samples_path, cps: @cps)
      end

      def reload_pattern
        pattern = load_pattern(@path)
        return unless pattern

        setup_runner unless @runner
        @runner.play(pattern)
        @current_pattern = pattern
        puts "[#{timestamp}] Pattern reloaded"
      end

      def timestamp
        Time.now.strftime("%H:%M:%S")
      end
    end
  end
end
