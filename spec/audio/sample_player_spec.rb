# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::SamplePlayer do
  # テスト用のダミーサンプルデータ
  class DummySampleData
    attr_reader :samples, :sample_rate

    def initialize(samples, sample_rate = 44_100)
      @samples = samples
      @sample_rate = sample_rate
    end

    def empty?
      @samples.empty?
    end
  end

  describe "#trigger" do
    it "starts playback with default gain and speed" do
      data = DummySampleData.new([0.5] * 100)
      player = Strudel::Audio::SamplePlayer.new(data)

      refute player.playing?
      player.trigger
      assert player.playing?
    end

    it "accepts gain parameter" do
      data = DummySampleData.new([1.0] * 100)
      player = Strudel::Audio::SamplePlayer.new(data)

      player.trigger(gain: 0.5)
      samples = player.generate(10)

      assert_in_delta 0.5, samples[0], 0.01
    end

    it "accepts speed parameter" do
      # シンプルな波形: 0, 0.5, 1.0, 0.5, 0 ...
      data = DummySampleData.new([0.0, 0.5, 1.0, 0.5, 0.0] * 20)
      player = Strudel::Audio::SamplePlayer.new(data)

      # speed=2.0 で2倍速再生
      player.trigger(speed: 2.0)
      samples = player.generate(10)

      # 2倍速なので、位置が2ずつ進む
      # position: 0, 2, 4, 6, 8...
      assert player.playing?
    end
  end

  describe "#generate" do
    it "produces audio samples" do
      data = DummySampleData.new([0.5] * 100)
      player = Strudel::Audio::SamplePlayer.new(data)

      player.trigger
      samples = player.generate(10)

      assert_equal 10, samples.length
      samples.each { |s| assert_in_delta 0.5, s, 0.01 }
    end

    it "stops when sample ends" do
      data = DummySampleData.new([0.5] * 10)
      player = Strudel::Audio::SamplePlayer.new(data)

      player.trigger
      _samples = player.generate(20)

      refute player.playing?
    end

    it "returns silence when not playing" do
      data = DummySampleData.new([0.5] * 100)
      player = Strudel::Audio::SamplePlayer.new(data)

      samples = player.generate(10)

      assert_equal 10, samples.length
      samples.each { |s| assert_equal 0.0, s }
    end
  end
end
