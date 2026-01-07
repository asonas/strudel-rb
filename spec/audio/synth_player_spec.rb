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
      left, right = player.generate(100)

      assert_equal 100, left.length
      assert_equal 100, right.length
      assert left.any? { |s| s != 0.0 }
    end

    it "stops after the given duration with a short release tail" do
      player = Strudel::Audio::SynthPlayer.new(:sine, sample_rate: 1000)
      player.trigger(frequency: 440, duration: 0.01) # 10ms hold

      player.generate(5)
      assert player.playing?

      player.generate(30) # hold + release should be done
      refute player.playing?
    end

    it "applies attack envelope" do
      player = Strudel::Audio::SynthPlayer.new(:sine, sample_rate: 1000)
      player.trigger(frequency: 100, duration: 0.2, attack: 0.05, decay: 0.05, sustain: 1.0, release: 0.01)

      early = player.generate(10).first.map(&:abs).sum / 10.0
      mid = player.generate(60).first.map(&:abs).sum / 60.0

      assert mid > early, "Attack should increase amplitude over time"
    end

    it "supports FM modulation" do
      base = Strudel::Audio::SynthPlayer.new(:sine, sample_rate: 1000)
      base.trigger(frequency: 100, duration: 0.2)
      base_samples = base.generate(50).first

      fm = Strudel::Audio::SynthPlayer.new(:sine, sample_rate: 1000)
      fm.trigger(frequency: 100, duration: 0.2, fmi: 0.8, fmh: 1.0, fmwave: "sine")
      fm_samples = fm.generate(50).first

      refute_equal base_samples, fm_samples
      assert fm_samples.all?(&:finite?)
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
