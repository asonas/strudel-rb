# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::Oscillator do
  describe "#initialize" do
    it "creates an oscillator with a waveform type" do
      osc = Strudel::Audio::Oscillator.new(:sine)

      assert_instance_of Strudel::Audio::Oscillator, osc
    end
  end

  describe "#generate" do
    it "generates sine wave samples" do
      osc = Strudel::Audio::Oscillator.new(:sine, sample_rate: 44100)
      samples = osc.generate(frequency: 440, frame_count: 100)

      assert_equal 100, samples.length
      # Sine wave should be between -1 and 1
      assert samples.all? { |s| s >= -1.0 && s <= 1.0 }
    end

    it "generates sawtooth wave samples" do
      osc = Strudel::Audio::Oscillator.new(:sawtooth, sample_rate: 44100)
      samples = osc.generate(frequency: 440, frame_count: 100)

      assert_equal 100, samples.length
      assert samples.all? { |s| s >= -1.0 && s <= 1.0 }
    end

    it "generates square wave samples" do
      osc = Strudel::Audio::Oscillator.new(:square, sample_rate: 44100)
      samples = osc.generate(frequency: 440, frame_count: 100)

      assert_equal 100, samples.length
      # Square wave should be either -1 or 1
      assert samples.all? { |s| s == -1.0 || s == 1.0 }
    end

    it "generates triangle wave samples" do
      osc = Strudel::Audio::Oscillator.new(:triangle, sample_rate: 44100)
      samples = osc.generate(frequency: 440, frame_count: 100)

      assert_equal 100, samples.length
      assert samples.all? { |s| s >= -1.0 && s <= 1.0 }
    end

    it "generates supersaw samples" do
      osc = Strudel::Audio::Oscillator.new(:supersaw, sample_rate: 44100, voices: 7)
      samples = osc.generate(frequency: 440, frame_count: 100)

      assert_equal 100, samples.length
      assert samples.all?(&:finite?)
    end
  end
end
