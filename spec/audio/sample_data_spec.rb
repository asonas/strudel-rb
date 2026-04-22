# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::SampleData do
  it "computes duration_seconds from channel length and sample_rate" do
    channels = [Array.new(44_100, 0.0)]  # 1 second at 44.1 kHz
    data = Strudel::Audio::SampleData.new(channels, 44_100)
    assert_in_delta 1.0, data.duration_seconds, 1e-9
  end

  it "uses the minimum channel length for duration_seconds" do
    channels = [Array.new(44_100, 0.0), Array.new(22_050, 0.0)]
    data = Strudel::Audio::SampleData.new(channels, 44_100)
    assert_in_delta 0.5, data.duration_seconds, 1e-9
  end

  it "returns 0.0 when empty" do
    data = Strudel::Audio::SampleData.silent
    assert_equal 0.0, data.duration_seconds
  end
end
