# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::SynthPlayer do
  describe "#initialize" do
    it "creates a synth player with waveform" do
      player = Strudel::Audio::SynthPlayer.new(:sawtooth)

      assert_instance_of Strudel::Audio::SynthPlayer, player
    end
  end

  describe "#trigger" do
    it "starts playing with given frequency" do
      player = Strudel::Audio::SynthPlayer.new(:sine)
      player.trigger(frequency: 440)

      assert player.playing?
    end

    it "accepts note parameter as MIDI note number" do
      player = Strudel::Audio::SynthPlayer.new(:sine)
      player.trigger(note: 69) # A4 = 440Hz

      assert player.playing?
    end
  end

  describe "#generate" do
    it "generates audio samples" do
      player = Strudel::Audio::SynthPlayer.new(:sine)
      player.trigger(frequency: 440)
      samples = player.generate(100)

      assert_equal 100, samples.length
      assert samples.any? { |s| s != 0.0 }
    end

    it "applies decay envelope" do
      player = Strudel::Audio::SynthPlayer.new(:sine, decay: 0.1)
      player.trigger(frequency: 440)

      # Generate enough samples for decay to happen (0.1s = 4410 samples at 44100Hz)
      samples1 = player.generate(1000)
      samples2 = player.generate(1000)
      samples3 = player.generate(1000)
      samples4 = player.generate(1000)
      samples5 = player.generate(1000)

      # After decay, amplitude should be lower
      avg1 = samples1.map(&:abs).sum / samples1.length
      avg5 = samples5.map(&:abs).sum / samples5.length

      assert avg5 < avg1, "Decay should reduce amplitude over time"
    end
  end

  describe "#stop" do
    it "stops the player" do
      player = Strudel::Audio::SynthPlayer.new(:sine)
      player.trigger(frequency: 440)
      player.stop

      refute player.playing?
    end
  end
end
