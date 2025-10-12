# frozen_string_literal: true

module Strudel
  class State
    attr_reader :span, :controls

    def initialize(span, controls = {})
      @span = span
      @controls = controls
    end

    # 新しいspanでStateを作成
    def set_span(new_span)
      State.new(new_span, @controls)
    end

    # 新しいcontrolsでStateを作成
    def set_controls(new_controls)
      State.new(@span, new_controls)
    end

    def inspect
      "State(span: #{@span.inspect}, controls: #{@controls.inspect})"
    end
  end
end
