# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::SamplePlayer do
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

  describe "#trigger with begin_frac / end_frac" do
    it "begin_frac: 0.5 starts playback from the midpoint of the sample" do
      ramp = (0...100).map { |i| i / 100.0 }
      data = DummySampleData.new([ramp.dup, ramp.dup])
      player = Strudel::Audio::SamplePlayer.new(data)

      player.trigger(begin_frac: 0.5)
      left, _right = player.generate(10)

      assert_in_delta 0.5, left[0], 0.02
    end

    it "end_frac: 0.5 stops playback at the midpoint of the sample" do
      ramp = (0...100).map { |i| i / 100.0 }
      data = DummySampleData.new([ramp.dup, ramp.dup])
      player = Strudel::Audio::SamplePlayer.new(data)

      player.trigger(end_frac: 0.5)
      player.generate(200)

      refute player.playing?, "player should stop once end_frac reached"
    end

    it "begin_frac + end_frac defines a slice in the middle of the sample" do
      ramp = (0...100).map { |i| i / 100.0 }
      data = DummySampleData.new([ramp.dup, ramp.dup])
      player = Strudel::Audio::SamplePlayer.new(data)

      player.trigger(begin_frac: 0.25, end_frac: 0.5)
      left, _right = player.generate(30)

      assert_in_delta 0.25, left[0], 0.02
      refute player.playing?
    end

    it "defaults to full-sample playback when begin_frac/end_frac are omitted" do
      ramp = (0...100).map { |i| i / 100.0 }
      data = DummySampleData.new([ramp.dup, ramp.dup])
      player = Strudel::Audio::SamplePlayer.new(data)

      player.trigger
      left, _right = player.generate(10)

      assert_in_delta 0.0, left[0], 0.02
    end
  end
end
