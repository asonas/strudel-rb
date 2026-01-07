# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::FilterEnvelope do
  describe "#process" do
    it "modulates cutoff exponentially in octaves like Strudel (positive lpenv)" do
      env = Strudel::Audio::FilterEnvelope.new(sample_rate: 1000)
      env.configure(
        base_frequency: 100.0,
        env: 1.0,
        anchor: 0.0,
        attack: 0.001,
        decay: 0.001,
        sustain: 0.0,
        release: 0.01
      )

      env.trigger

      v0 = env.process
      v1 = env.process

      assert_in_delta 100.0, v0, 0.5
      assert_in_delta 200.0, v1, 1.0
    end

    it "supports negative lpenv by inverting the sweep direction" do
      env = Strudel::Audio::FilterEnvelope.new(sample_rate: 1000)
      env.configure(
        base_frequency: 100.0,
        env: -1.0,
        anchor: 0.0,
        attack: 0.001,
        decay: 0.001,
        sustain: 0.0,
        release: 0.01
      )

      env.trigger

      v0 = env.process
      v1 = env.process

      assert_in_delta 200.0, v0, 1.0
      assert_in_delta 100.0, v1, 0.5
    end
  end
end

