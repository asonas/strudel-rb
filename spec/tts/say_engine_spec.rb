# frozen_string_literal: true

require_relative "../spec_helper"
require "tmpdir"
require "fileutils"
require_relative "../../lib/strudel/tts/engine"
require_relative "../../lib/strudel/tts/say_engine"

describe Strudel::TTS::SayEngine do
  before do
    @engine = Strudel::TTS::SayEngine.new
  end

  it "has name :say" do
    assert_equal :say, @engine.name
  end

  describe "on macOS" do
    before do
      skip "macOS only" unless RUBY_PLATFORM.include?("darwin")
    end

    it "reports available when darwin and say exists" do
      assert @engine.available?
    end

    it "generates a non-empty WAV with a RIFF header" do
      Dir.mktmpdir do |dir|
        out = File.join(dir, "out.wav")
        @engine.generate(text: "test", voice: nil, rate: nil, output_path: out)

        assert File.exist?(out)
        assert File.size(out) > 44
        header = File.binread(out, 4)
        assert_equal "RIFF", header
      end
    end

    it "raises TTSGenerationError when say fails (invalid voice)" do
      Dir.mktmpdir do |dir|
        out = File.join(dir, "out.wav")
        assert_raises(Strudel::TTS::TTSGenerationError) do
          @engine.generate(text: "test", voice: "__not_a_real_voice__", rate: nil, output_path: out)
        end
      end
    end
  end

  describe "on non-macOS" do
    before do
      skip "non-macOS only" if RUBY_PLATFORM.include?("darwin")
    end

    it "reports unavailable" do
      refute @engine.available?
    end
  end
end
