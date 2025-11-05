# frozen_string_literal: true

module Strudel
  class State
    attr_reader :span, :controls

    def initialize(span, controls = {})
      @span = span
      @controls = controls
    end

    # Create a State with a new span
    def set_span(new_span)
      State.new(new_span, @controls)
    end

    # Create a State with new controls
    def set_controls(new_controls)
      State.new(@span, new_controls)
    end

    def inspect
      "State(span: #{@span.inspect}, controls: #{@controls.inspect})"
    end
  end
end
