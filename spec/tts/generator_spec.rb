# frozen_string_literal: true

require_relative "../spec_helper"
require "fileutils"
require "tmpdir"
require_relative "../../lib/strudel/tts/engine"
require_relative "../../lib/strudel/tts/generator"
require_relative "fake_engine"

describe Strudel::TTS::Generator do
  before do
    @cache_dir = Dir.mktmpdir("strudel-tts-test-")
    @fake = Strudel::TTS::FakeEngine.new
    @generator = Strudel::TTS::Generator.new(cache_dir: @cache_dir, engines: [@fake])
  end

  after do
    FileUtils.rm_rf(@cache_dir) if @cache_dir && File.directory?(@cache_dir)
  end

  it "generates a wav and returns its absolute path" do
    path = @generator.generate("hello")

    assert File.exist?(path)
    assert path.start_with?(@cache_dir)
    assert_equal ".wav", File.extname(path)
    assert_equal 1, @fake.call_count
  end

  it "caches by (text, voice, rate, engine) and reuses on second call" do
    p1 = @generator.generate("hello", voice: "Kyoko", rate: 180)
    p2 = @generator.generate("hello", voice: "Kyoko", rate: 180)

    assert_equal p1, p2
    assert_equal 1, @fake.call_count
  end

  it "regenerates when voice differs" do
    p1 = @generator.generate("hello", voice: "Kyoko")
    p2 = @generator.generate("hello", voice: "Samantha")

    refute_equal p1, p2
    assert_equal 2, @fake.call_count
  end

  it "regenerates when text differs" do
    p1 = @generator.generate("hello")
    p2 = @generator.generate("world")

    refute_equal p1, p2
    assert_equal 2, @fake.call_count
  end

  it "raises NoAvailableEngineError when all engines unavailable" do
    unavailable = Strudel::TTS::FakeEngine.new(available: false)
    generator = Strudel::TTS::Generator.new(cache_dir: @cache_dir, engines: [unavailable])

    assert_raises(Strudel::TTS::NoAvailableEngineError) do
      generator.generate("hello")
    end
  end

  it "selects the first available engine" do
    unavailable = Strudel::TTS::FakeEngine.new(available: false)
    available = Strudel::TTS::FakeEngine.new(available: true)
    generator = Strudel::TTS::Generator.new(cache_dir: @cache_dir, engines: [unavailable, available])

    generator.generate("hello")
    assert_equal 0, unavailable.call_count
    assert_equal 1, available.call_count
  end
end
