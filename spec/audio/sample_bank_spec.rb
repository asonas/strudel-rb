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
end
