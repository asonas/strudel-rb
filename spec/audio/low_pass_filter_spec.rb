# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::LowPassFilter do
  describe "#process" do
    it "stays finite for high lpq (Q) values" do
      filter = Strudel::Audio::LowPassFilter.new(sample_rate: 44_100, cutoff: 1000.0, resonance: 30.0)

      # Impulse input
      input = Array.new(1000, 0.0)
      input[0] = 1.0

      output = filter.process(input)

      assert output.all?(&:finite?)
    end
  end

  describe "#resonance=" do
    it "clamps lpq to 0..50" do
      filter = Strudel::Audio::LowPassFilter.new(resonance: 0.0)
      filter.resonance = 999.0

      assert_in_delta 50.0, filter.resonance, 0.0001
    end
  end
end

