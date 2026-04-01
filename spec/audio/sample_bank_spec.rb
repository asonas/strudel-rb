# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::SampleBank do
  let(:fixtures_path) { File.expand_path("../fixtures/samples", __dir__) }
  let(:bank) { Strudel::Audio::SampleBank.new(fixtures_path) }

  describe "#pitch_map" do
    it "returns integer hash when pitch.json exists" do
      result = bank.pitch_map("pitched_test")

      assert_instance_of Hash, result
      assert_equal({ 0 => 60, 1 => 72 }, result)
    end

    it "returns nil when no pitch.json exists" do
      result = bank.pitch_map("unpitched_test")

      assert_nil result
    end

    it "caches the result" do
      first = bank.pitch_map("pitched_test")
      second = bank.pitch_map("pitched_test")

      assert_same first, second
    end
  end

  describe "#get_pitched" do
    it "picks closest sample and calculates speed for E4 (64)" do
      sample, speed = bank.get_pitched("pitched_test", 64)

      refute sample.empty?
      # E4=64, closest is 0.wav (C4=60), speed = 2^(4/12) ≈ 1.2599
      assert_in_delta 1.2599, speed, 0.001
    end

    it "picks closest sample and calculates speed for B4 (71)" do
      sample, speed = bank.get_pitched("pitched_test", 71)

      refute sample.empty?
      # B4=71, closest is 1.wav (C5=72), speed = 2^(-1/12) ≈ 0.9439
      assert_in_delta 0.9439, speed, 0.001
    end

    it "returns speed 1.0 for exact match C4 (60)" do
      sample, speed = bank.get_pitched("pitched_test", 60)

      refute sample.empty?
      assert_in_delta 1.0, speed, 0.0001
    end

    it "falls back with speed 1.0 for unpitched sound" do
      sample, speed = bank.get_pitched("unpitched_test", 64)

      refute sample.empty?
      assert_in_delta 1.0, speed, 0.0001
    end
  end
end
