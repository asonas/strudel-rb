# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::SampleBank do
  describe "#load_path" do
    before do
      @bank = Strudel::Audio::SampleBank.new
      @fixture = File.expand_path("../fixtures/tts/test_voice.wav", __dir__)
      raise "fixture missing: #{@fixture}" unless File.exist?(@fixture)
    end

    it "loads WAV from an absolute path" do
      data = @bank.load_path(@fixture)
      refute data.empty?
      assert_equal 44_100, data.sample_rate
      assert data.length > 0
    end

    it "returns the same SampleData on repeated calls (caches by path)" do
      first = @bank.load_path(@fixture)
      second = @bank.load_path(@fixture)
      assert_same first, second
    end

    it "returns silent SampleData when path does not exist" do
      data = @bank.load_path("/nonexistent/path.wav")
      assert data.empty?
    end
  end
end
