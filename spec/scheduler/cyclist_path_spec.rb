# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Scheduler::Cyclist do
  describe "sample by :path" do
    before do
      @fixture = File.expand_path("../fixtures/tts/test_voice.wav", __dir__)
      raise "fixture missing: #{@fixture}" unless File.exist?(@fixture)
      @cyclist = Strudel::Scheduler::Cyclist.new(cps: 1.0)
    end

    it "triggers a sample loaded from :path" do
      pattern = Strudel::Pattern.pure(s: "say", path: @fixture)
      @cyclist.set_pattern(pattern)

      # Generate exactly one cycle worth of samples
      frames = @cyclist.sample_rate  # 1 second at cps=1 = 1 cycle
      left, right = @cyclist.generate(frames)

      # At least some audio energy should exist in the output
      assert left.any? { |v| v.abs > 0.0001 }
      assert_equal frames, left.length
      assert_equal frames, right.length
    end

    it "falls back to normal sample lookup when :path absent" do
      pattern = Strudel::Pattern.pure(s: "bd", n: 0)
      @cyclist.set_pattern(pattern)

      left, _right = @cyclist.generate(@cyclist.sample_rate)
      assert_equal @cyclist.sample_rate, left.length
    end
  end
end
