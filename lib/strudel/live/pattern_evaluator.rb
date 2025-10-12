# frozen_string_literal: true

module Strudel
  module Live
    class PatternEvaluator
      include DSL

      def evaluate_string(code)
        instance_eval(code)
      end

      def evaluate_file(path)
        content = File.read(path)
        evaluate_string(content)
      end
    end
  end
end
