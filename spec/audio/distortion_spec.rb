# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::Distortion do
  describe "#process_sample" do
    it "returns unchanged sample when amount is 0" do
      dist = Strudel::Audio::Distortion.new(amount: 0.0, type: :sinefold)

      assert_in_delta 0.5, dist.process_sample(0.5), 0.001
      assert_in_delta(-0.3, dist.process_sample(-0.3), 0.001)
    end

    it "distorts signal with sinefold type" do
      dist = Strudel::Audio::Distortion.new(amount: 5.0, type: :sinefold)

      # Sinefold should wrap the signal, changing the waveform
      output = dist.process_sample(0.5)
      assert output.finite?
      assert output.abs <= 1.0
    end

    it "distorts signal with fold type" do
      dist = Strudel::Audio::Distortion.new(amount: 5.0, type: :fold)

      output = dist.process_sample(0.5)
      assert output.finite?
      assert output.abs <= 1.0
    end

    it "distorts signal with diode type" do
      dist = Strudel::Audio::Distortion.new(amount: 5.0, type: :diode)

      output = dist.process_sample(0.5)
      assert output.finite?
      assert output >= 0.0, "Diode should only pass positive values"
    end

    it "supports soft clipping type" do
      dist = Strudel::Audio::Distortion.new(amount: 5.0, type: :soft)

      output = dist.process_sample(0.8)
      assert output.finite?
      assert output.abs <= 1.0
    end

    it "supports hard clipping type" do
      dist = Strudel::Audio::Distortion.new(amount: 5.0, type: :hard)

      output = dist.process_sample(0.8)
      assert output.finite?
      assert output.abs <= 1.0
    end
  end

  describe "#process" do
    it "processes an array of samples" do
      dist = Strudel::Audio::Distortion.new(amount: 3.0, type: :sinefold)
      input = [0.1, 0.3, 0.5, 0.7, 0.9]
      output = dist.process(input)

      assert_equal 5, output.length
      assert output.all?(&:finite?)
    end
  end

  describe "#amount=" do
    it "updates the distortion amount" do
      dist = Strudel::Audio::Distortion.new(amount: 1.0, type: :sinefold)
      dist.amount = 5.0

      assert_in_delta 5.0, dist.amount, 0.001
    end
  end

  describe "post_gain (distortvol)" do
    it "applies post-distortion gain" do
      dist = Strudel::Audio::Distortion.new(amount: 3.0, type: :sinefold, post_gain: 0.5)
      output_half = dist.process_sample(0.5)

      dist_full = Strudel::Audio::Distortion.new(amount: 3.0, type: :sinefold, post_gain: 1.0)
      output_full = dist_full.process_sample(0.5)

      assert output_half.abs < output_full.abs, "Post gain should scale output"
    end
  end
end
