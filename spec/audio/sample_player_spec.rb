# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::SamplePlayer do
  # テスト用のダミーサンプルデータ
  class DummySampleData
    attr_reader :channels, :sample_rate

    def initialize(channels, sample_rate = 44_100)
      @channels = channels
      @sample_rate = sample_rate
    end

    def empty?
      @channels.empty? || @channels.all?(&:empty?)
    end
  end

  describe "#trigger" do
    it "starts playback with default gain and speed" do
      data = DummySampleData.new([[0.5] * 100])
      player = Strudel::Audio::SamplePlayer.new(data)

      refute player.playing?
      player.trigger
      assert player.playing?
    end

    it "accepts gain parameter" do
      data = DummySampleData.new([[1.0] * 100])
      player = Strudel::Audio::SamplePlayer.new(data)

      player.trigger(gain: 0.5)
      left, right = player.generate(10)

      assert_in_delta 0.5, left[0], 0.01
      assert_in_delta 0.5, right[0], 0.01
    end

    it "accepts speed parameter" do
      # シンプルな波形: 0, 0.5, 1.0, 0.5, 0 ...
      data = DummySampleData.new([[0.0, 0.5, 1.0, 0.5, 0.0] * 20])
      player = Strudel::Audio::SamplePlayer.new(data)

      # speed=2.0 で2倍速再生
      player.trigger(speed: 2.0)
      _left, _right = player.generate(10)

      # 2倍速なので、位置が2ずつ進む
      # position: 0, 2, 4, 6, 8...
      assert player.playing?
    end

    it "applies attack envelope" do
      data = DummySampleData.new([[1.0] * 1000], 1000)
      player = Strudel::Audio::SamplePlayer.new(data, 1000)

      player.trigger(gain: 1.0, duration: 0.1, attack: 0.05, decay: 0.05, sustain: 1.0, release: 0.01)
      early = player.generate(10).first.map(&:abs).sum / 10.0
      mid = player.generate(60).first.map(&:abs).sum / 60.0

      assert mid > early, "Attack should increase amplitude over time"
    end
  end

  describe "#generate" do
    it "produces audio samples" do
      data = DummySampleData.new([[0.5] * 100])
      player = Strudel::Audio::SamplePlayer.new(data)

      player.trigger
      left, right = player.generate(10)

      assert_equal 10, left.length
      assert_equal 10, right.length
      left.each { |s| assert_in_delta 0.5, s, 0.01 }
      right.each { |s| assert_in_delta 0.5, s, 0.01 }
    end

    it "stops when sample ends" do
      data = DummySampleData.new([[0.5] * 10])
      player = Strudel::Audio::SamplePlayer.new(data)

      player.trigger
      _left, _right = player.generate(20)

      refute player.playing?
    end

    it "returns silence when not playing" do
      data = DummySampleData.new([[0.5] * 100])
      player = Strudel::Audio::SamplePlayer.new(data)

      left, right = player.generate(10)

      assert_equal 10, left.length
      assert_equal 10, right.length
      left.each { |s| assert_equal 0.0, s }
      right.each { |s| assert_equal 0.0, s }
    end
  end
end
