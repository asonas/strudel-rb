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

  describe "HPF support" do
    it "accepts hpf parameter and attenuates low frequencies" do
      # Without HPF
      player_no_hpf = Strudel::Audio::SynthPlayer.new(:sawtooth, sample_rate: 44_100)
      player_no_hpf.trigger(frequency: 100, duration: 0.1)
      samples_no_hpf = player_no_hpf.generate(4410).first

      # With HPF at 5000 Hz
      player_hpf = Strudel::Audio::SynthPlayer.new(:sawtooth, sample_rate: 44_100)
      player_hpf.trigger(frequency: 100, duration: 0.1, hpf: 5000.0)
      samples_hpf = player_hpf.generate(4410).first

      rms_no_hpf = Math.sqrt(samples_no_hpf.sum { |s| s * s } / samples_no_hpf.length)
      rms_hpf = Math.sqrt(samples_hpf.sum { |s| s * s } / samples_hpf.length)

      assert rms_hpf < rms_no_hpf, "HPF should reduce energy of a low-frequency signal"
    end
  end

  describe "Distortion support" do
    it "accepts distort parameter and changes the waveform" do
      player_clean = Strudel::Audio::SynthPlayer.new(:sine, sample_rate: 44_100)
      player_clean.trigger(frequency: 440, duration: 0.1)
      samples_clean = player_clean.generate(1000).first

      player_dist = Strudel::Audio::SynthPlayer.new(:sine, sample_rate: 44_100)
      player_dist.trigger(frequency: 440, duration: 0.1, distort: 5.0, distorttype: "sinefold")
      samples_dist = player_dist.generate(1000).first

      refute_equal samples_clean, samples_dist
      assert samples_dist.all?(&:finite?)
    end
  end

  describe "Pitch envelope (glide) support" do
    it "accepts penv and pdecay parameters" do
      player = Strudel::Audio::SynthPlayer.new(:sine, sample_rate: 44_100)
      # penv = 12 means start 12 semitones (1 octave) above target
      player.trigger(frequency: 440, duration: 0.1, penv: 12.0, pdecay: 0.03)
      assert player.playing?
    end

    it "starts at offset frequency and decays to target" do
      sample_rate = 44_100

      # Without pitch envelope
      player_no_env = Strudel::Audio::SynthPlayer.new(:sine, sample_rate: sample_rate)
      player_no_env.trigger(frequency: 440, duration: 0.1)
      samples_no_env = player_no_env.generate(100).first

      # With pitch envelope: start 12 semitones above (880Hz -> 440Hz)
      player_env = Strudel::Audio::SynthPlayer.new(:sine, sample_rate: sample_rate)
      player_env.trigger(frequency: 440, duration: 0.1, penv: 12.0, pdecay: 0.05)
      samples_env = player_env.generate(100).first

      # The samples should differ because the pitch envelope changes the frequency
      refute_equal samples_no_env, samples_env
      assert samples_env.all?(&:finite?)
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
