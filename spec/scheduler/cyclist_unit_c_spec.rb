# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Scheduler::Cyclist do
  describe "unit: \"c\" handling" do
    before do
      @fixture = File.expand_path("../fixtures/tts/test_voice.wav", __dir__)
      raise "fixture missing: #{@fixture}" unless File.exist?(@fixture)
      @cyclist = Strudel::Scheduler::Cyclist.new(cps: 1.0)
    end

    it "multiplies speed by sample duration when unit is \"c\"" do
      # fixture is 0.1s long. With speed=1 and unit="c", final speed = 1 * 0.1 = 0.1
      # which means the sample plays 10x slower.
      pattern = Strudel::Pattern.pure(s: "say", path: @fixture, speed: 1.0, unit: "c")

      active = capture_active_voice(pattern)
      refute_nil active
      effective_speed = active.player.instance_variable_get(:@speed)
      assert_in_delta 0.1, effective_speed, 1e-6
    end

    it "does not alter speed when unit is not set" do
      pattern = Strudel::Pattern.pure(s: "say", path: @fixture, speed: 1.0)

      active = capture_active_voice(pattern)
      refute_nil active
      effective_speed = active.player.instance_variable_get(:@speed)
      assert_in_delta 1.0, effective_speed, 1e-6
    end

    private

    def capture_active_voice(pattern)
      @cyclist.set_pattern(pattern)
      # Use a small frame count so the 0.1s fixture does not finish playing
      # before we inspect @active_players (generate removes finished players).
      @cyclist.generate(1024)
      @cyclist.instance_variable_get(:@active_players).first
    end
  end
end
