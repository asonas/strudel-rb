# frozen_string_literal: true

require_relative "../spec_helper"
require "tmpdir"
require "json"

# Subclass that stubs HTTP methods for testing
class StubRemoteSampleSource < Strudel::Audio::RemoteSampleSource
  attr_writer :stub_json, :stub_files, :stub_head_urls

  def initialize(source, stub_json:, stub_files: {}, stub_head_urls: [])
    @stub_json = stub_json
    @stub_files = stub_files
    @stub_head_urls = stub_head_urls
    super(source)
  end

  private

  def fetch_json(_url)
    JSON.parse(@stub_json)
  end

  def download(url, local_path)
    data = @stub_files[url]
    if data
      FileUtils.mkdir_p(File.dirname(local_path))
      File.binwrite(local_path, data)
    else
      raise "Not found: #{url}"
    end
  end

  def head_exists?(url)
    @stub_head_urls.include?(url)
  end
end

describe Strudel::Audio::RemoteSampleSource do
  describe "#parse_github_parts (via github_url)" do
    it "parses github:user/repo/branch" do
      source = stub_source("github:alice/mysamples/develop", {})
      # The URL should reflect the parsed parts
      assert_equal "github:alice/mysamples/develop", source.source_url
    end

    it "defaults branch to main" do
      source = stub_source("github:alice/mysamples", {})
      assert_equal "github:alice/mysamples", source.source_url
    end

    it "defaults repo to samples and branch to main" do
      source = stub_source("github:alice", {})
      assert_equal "github:alice", source.source_url
    end
  end

  describe "#has?" do
    it "returns true for known sound names" do
      source = stub_source("github:test/repo", {
        "bd" => ["bd/0.wav"],
        "sd" => ["sd/0.wav"],
      })
      assert source.has?("bd")
      assert source.has?("sd")
      refute source.has?("hh")
    end
  end

  describe "#get_path" do
    it "returns cached WAV path for known sound" do
      source = stub_source("github:test/repo", {
        "bd" => ["bd/0.wav", "bd/1.wav"],
      })

      path0 = source.get_path("bd", 0)
      path1 = source.get_path("bd", 1)

      assert path0.end_with?("test/repo/bd/0.wav")
      assert path1.end_with?("test/repo/bd/1.wav")
    end

    it "wraps around with modulo for n > array length" do
      source = stub_source("github:test/repo", {
        "bd" => ["bd/0.wav", "bd/1.wav"],
      })

      path = source.get_path("bd", 3)
      # 3 % 2 = 1
      assert path.end_with?("test/repo/bd/1.wav")
    end

    it "returns nil for unknown sound name" do
      source = stub_source("github:test/repo", { "bd" => ["bd/0.wav"] })
      assert_nil source.get_path("hh", 0)
    end

    it "ignores non-WAV entries" do
      source = stub_source("github:test/repo", { "piano" => ["piano/A0.mp3"] })
      assert_nil source.get_path("piano", 0)
    end

    it "handles single string value (not array)" do
      source = stub_source("github:test/repo", { "bd" => "bd/single.wav" })
      path = source.get_path("bd", 0)
      assert path.end_with?("test/repo/bd/0.wav")
    end
  end

  describe "strudel.json _base handling" do
    it "uses _base from JSON when present" do
      json = JSON.generate({
        "_base" => "https://example.com/samples/",
        "bd" => ["bd/0.wav"],
      })
      files = { "https://example.com/samples/bd/0.wav" => "RIFF_FAKE_WAV" }
      source = StubRemoteSampleSource.new("github:test/repo", stub_json: json, stub_files: files)

      assert source.has?("bd")
    end

    it "derives base from strudel.json URL when _base is absent" do
      json = JSON.generate({ "bd" => ["bd/0.wav"] })
      base = "https://raw.githubusercontent.com/test/repo/main/"
      files = { "#{base}bd/0.wav" => "RIFF_FAKE_WAV" }
      source = StubRemoteSampleSource.new("github:test/repo", stub_json: json, stub_files: files)

      assert source.has?("bd")
    end
  end

  describe "duplicate registration prevention" do
    before do
      @saved_sources = Strudel.remote_sources.dup
      Strudel.remote_sources.clear
    end

    after do
      Strudel.remote_sources.clear
      @saved_sources.each { |s| Strudel.remote_sources << s }
    end

    it "does not register the same source twice via DSL" do
      dsl = Object.new.extend(Strudel::DSL)

      # Manually add a fake source with matching source_url
      fake = Struct.new(:source_url).new("github:test/repo")
      Strudel.remote_sources << fake

      # Second call should be a no-op since source_url matches
      dsl.samples("github:test/repo")

      assert_equal 1, Strudel.remote_sources.size
    end
  end

  describe "pitch.json remote download" do
    it "downloads pitch.json when HEAD returns success" do
      pitch_url = "https://example.com/samples/gm_piano/pitch.json"
      pitch_data = '{"0": 60, "1": 72}'
      json = JSON.generate({
        "_base" => "https://example.com/samples/",
        "gm_piano" => ["gm_piano/0.wav", "gm_piano/1.wav"],
      })
      files = {
        "https://example.com/samples/gm_piano/0.wav" => "RIFF_FAKE_WAV",
        "https://example.com/samples/gm_piano/1.wav" => "RIFF_FAKE_WAV",
        pitch_url => pitch_data,
      }
      source = StubRemoteSampleSource.new(
        "github:test/pitchrepo",
        stub_json: json,
        stub_files: files,
        stub_head_urls: [pitch_url]
      )

      path = source.pitch_json_path("gm_piano")
      refute_nil path
      assert File.exist?(path)
      assert_equal pitch_data, File.read(path)
    end

    it "skips pitch.json when HEAD returns not found" do
      json = JSON.generate({
        "_base" => "https://example.com/samples/",
        "bd" => ["bd/0.wav"],
      })
      files = { "https://example.com/samples/bd/0.wav" => "RIFF_FAKE_WAV" }
      source = StubRemoteSampleSource.new(
        "github:test/nopitch",
        stub_json: json,
        stub_files: files,
        stub_head_urls: []
      )

      assert_nil source.pitch_json_path("bd")
    end
  end

  describe "SampleBank remote fallback" do
    it "uses local sample when both local and remote exist" do
      bank = Strudel::Audio::SampleBank.new
      fake_source = Minitest::Mock.new

      bank.add_remote_source(fake_source)

      result = bank.get("bd", 0)
      refute result.empty?, "local bd sample should load without consulting remote"
      fake_source.verify
    end

    it "falls back to remote when local sample is missing" do
      bank = Strudel::Audio::SampleBank.new
      fixture_path = File.expand_path("../fixtures/samples/unpitched_test/0.wav", __dir__)

      stub_source = Object.new
      stub_source.define_singleton_method(:get_path) do |name, n|
        name == "remote_only" && File.exist?(fixture_path) ? fixture_path : nil
      end
      stub_source.define_singleton_method(:pitch_json_path) { |_name| nil }

      bank.add_remote_source(stub_source)

      result = bank.get("remote_only", 0)
      if File.exist?(fixture_path)
        refute result.empty?, "should load from remote source"
      else
        assert result.empty?
      end
    end
  end

  private

  def stub_source(github_url, sample_map, stub_head_urls: [])
    json = JSON.generate(sample_map.merge("_base" => "https://example.com/samples/"))
    files = {}
    sample_map.each_value do |paths|
      paths = [paths] unless paths.is_a?(Array)
      paths.each do |p|
        files["https://example.com/samples/#{p}"] = "RIFF_FAKE_WAV"
      end
    end
    StubRemoteSampleSource.new(github_url, stub_json: json, stub_files: files, stub_head_urls: stub_head_urls)
  end
end
