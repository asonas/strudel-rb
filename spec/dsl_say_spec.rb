# frozen_string_literal: true

require_relative "spec_helper"
require "tmpdir"
require_relative "tts/fake_engine"

describe Strudel::DSL do
  include Strudel::DSL

  describe "#say" do
    before do
      @cache_dir = Dir.mktmpdir("strudel-say-dsl-")
      @fake = Strudel::TTS::FakeEngine.new
      @original_generator = Strudel.tts_generator
      Strudel.tts_generator = Strudel::TTS::Generator.new(cache_dir: @cache_dir, engines: [@fake])
    end

    after do
      Strudel.tts_generator = @original_generator
      FileUtils.rm_rf(@cache_dir) if @cache_dir && File.directory?(@cache_dir)
    end

    it "returns a Pattern" do
      pattern = say("hello")
      assert_kind_of Strudel::Pattern, pattern
    end

    it "produces a hap with :path pointing at the generated wav" do
      pattern = say("hello")
      hap = pattern.query_arc(0, 1).first

      assert hap.value.is_a?(Hash)
      assert File.exist?(hap.value[:path])
      assert_equal "say", hap.value[:s]
    end

    it "generates different paths for different voices" do
      p1 = say("hello", voice: "A")
      p2 = say("hello", voice: "B")
      path1 = p1.query_arc(0, 1).first.value[:path]
      path2 = p2.query_arc(0, 1).first.value[:path]

      refute_equal path1, path2
    end

    it "produces one hap per cycle" do
      pattern = say("hello")
      haps = pattern.query_arc(0, 3)
      assert_equal 3, haps.length
    end

    it "supports chainable effects" do
      pattern = say("hello").gain(0.5)
      hap = pattern.query_arc(0, 1).first
      assert_equal 0.5, hap.value[:gain]
    end

    it "allows fit to be chained" do
      pattern = say("hello").fit
      hap = pattern.query_arc(0, 1).first
      assert_equal "c", hap.value[:unit]
    end
  end

  describe "#say error handling" do
    it "raises NoAvailableEngineError when no engines available" do
      original = Strudel.tts_generator
      Strudel.tts_generator = Strudel::TTS::Generator.new(cache_dir: Dir.mktmpdir, engines: [])

      assert_raises(Strudel::TTS::NoAvailableEngineError) do
        say("hello")
      end
    ensure
      Strudel.tts_generator = original
    end
  end
end
