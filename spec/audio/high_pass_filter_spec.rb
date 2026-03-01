# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::HighPassFilter do
  describe "#process" do
    it "attenuates low frequencies" do
      filter = Strudel::Audio::HighPassFilter.new(sample_rate: 44_100, cutoff: 5000.0)

      # Generate a low-frequency sine wave (100 Hz)
      samples = Array.new(4410) do |i|
        Math.sin(2.0 * Math::PI * 100.0 * i / 44_100.0)
      end

      output = filter.process(samples)

      # RMS of output should be significantly less than input RMS
      input_rms = Math.sqrt(samples.sum { |s| s * s } / samples.length)
      output_rms = Math.sqrt(output.sum { |s| s * s } / output.length)

      assert output_rms < input_rms * 0.3, "HPF should attenuate low frequencies"
    end

    it "passes high frequencies" do
      filter = Strudel::Audio::HighPassFilter.new(sample_rate: 44_100, cutoff: 100.0)

      # Generate a high-frequency sine wave (5000 Hz)
      samples = Array.new(4410) do |i|
        Math.sin(2.0 * Math::PI * 5000.0 * i / 44_100.0)
      end

      output = filter.process(samples)

      # RMS of output should be close to input RMS
      input_rms = Math.sqrt(samples.sum { |s| s * s } / samples.length)
      output_rms = Math.sqrt(output.sum { |s| s * s } / output.length)

      assert output_rms > input_rms * 0.7, "HPF should pass high frequencies"
    end

    it "stays finite for high resonance values" do
      filter = Strudel::Audio::HighPassFilter.new(sample_rate: 44_100, cutoff: 1000.0, resonance: 30.0)

      input = Array.new(1000, 0.0)
      input[0] = 1.0

      output = filter.process(input)

      assert output.all?(&:finite?)
    end
  end

  describe "#resonance=" do
    it "clamps resonance to 0..50" do
      filter = Strudel::Audio::HighPassFilter.new(resonance: 0.0)
      filter.resonance = 999.0

      assert_in_delta 50.0, filter.resonance, 0.0001
    end
  end
end
