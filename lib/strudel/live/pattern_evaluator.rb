# frozen_string_literal: true

module Strudel
  module Live
    class PatternEvaluator
      include DSL

      def evaluate_string(code)
        clear_tracks if respond_to?(:clear_tracks)
        result = instance_eval(code)

        # If tracks were defined, auto-stack them (Strudel-like $:)
        if instance_variable_defined?(:@track_registry) && @track_registry && !@track_registry.empty?
          return tracks
        end

        result
      end

      def evaluate_file(path)
        content = File.read(path)
        evaluate_string(content)
      end
    end
  end
end
