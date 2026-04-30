# frozen_string_literal: true

require_relative "string_pattern_ops"

module Strudel
  module Live
    class PatternEvaluator
      include DSL

      def evaluate_string(code)
        clear_tracks if respond_to?(:clear_tracks)
        result = box_eval(code)

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

      private

      def box_eval(code)
        if box_mode?
          eval_in_box(code)
        else
          instance_eval(code)
        end
      end

      def box_mode?
        defined?(Ruby::Box) &&
          Ruby::Box.respond_to?(:enabled?) &&
          Ruby::Box.enabled?
      end

      # Evaluate user code inside a fresh Ruby::Box so that the
      # StringPatternOps monkey patch (and any other patches the user might
      # apply) is scoped to this single evaluation. Pattern objects flow back
      # out because Ruby::Box does not isolate object space, only constant
      # lookup and method tables.
      def eval_in_box(code)
        Thread.current[BOX_EVALUATOR_KEY] = self
        box = Ruby::Box.new
        box.eval(<<~RUBY)
          # Bridge the host Strudel module into the box. Constants defined in
          # the main box are not visible by default, so we expose them via
          # Ruby::Box.main and re-bind ::Strudel to the host module so that
          # user code can write `Strudel::Pattern` etc. naturally.
          host_strudel = Ruby::Box.main.const_get(:Strudel)
          ::Object.const_set(:Strudel, host_strudel) unless defined?(::Strudel)

          String.prepend(host_strudel::Live::StringPatternOps)

          # Thread-local crosses Box boundaries (Box does not isolate object
          # space), giving us a deprecation-free handle on the host evaluator.
          host_evaluator = Thread.current[#{BOX_EVALUATOR_KEY.inspect}]
          host_evaluator.instance_eval(#{code.dump})
        RUBY
      ensure
        Thread.current[BOX_EVALUATOR_KEY] = nil
      end

      BOX_EVALUATOR_KEY = :strudel_box_host_evaluator
      private_constant :BOX_EVALUATOR_KEY
    end
  end
end
