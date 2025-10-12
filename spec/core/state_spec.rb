# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::State do
  describe "#initialize" do
    it "creates state with span" do
      span = Strudel::TimeSpan.new(0, 1)
      state = Strudel::State.new(span)

      assert_equal span, state.span
      assert_equal({}, state.controls)
    end

    it "creates state with span and controls" do
      span = Strudel::TimeSpan.new(0, 1)
      controls = { cps: 0.5 }
      state = Strudel::State.new(span, controls)

      assert_equal span, state.span
      assert_equal controls, state.controls
    end
  end

  describe "#set_span" do
    it "returns new state with different span" do
      span1 = Strudel::TimeSpan.new(0, 1)
      span2 = Strudel::TimeSpan.new(1, 2)
      controls = { cps: 0.5 }
      state = Strudel::State.new(span1, controls)

      new_state = state.set_span(span2)

      assert_equal span2, new_state.span
      assert_equal controls, new_state.controls
      # Original state unchanged
      assert_equal span1, state.span
    end
  end

  describe "#set_controls" do
    it "returns new state with different controls" do
      span = Strudel::TimeSpan.new(0, 1)
      controls1 = { cps: 0.5 }
      controls2 = { cps: 1.0 }
      state = Strudel::State.new(span, controls1)

      new_state = state.set_controls(controls2)

      assert_equal controls2, new_state.controls
      assert_equal span, new_state.span
      # Original state unchanged
      assert_equal controls1, state.controls
    end
  end
end
