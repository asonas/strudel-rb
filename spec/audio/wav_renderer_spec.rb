# frozen_string_literal: true

require_relative "../spec_helper"
require "wavefile"
require "tmpdir"

describe Strudel::Audio::WavRenderer do
  before do
    @dsl = Object.new.extend(Strudel::DSL)
  end

  it "renders a sine pattern to a stereo WAV file" do
    cyclist = Strudel::Scheduler::Cyclist.new(sample_rate: 44_100, cps: 1.0)
    pat = @dsl.note("c4").s("sine").gain(0.5)
    cyclist.set_pattern(pat)

    renderer = Strudel::Audio::WavRenderer.new(cyclist)

    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.wav")
      renderer.render(cycles: 1, output_path: path)

      assert File.exist?(path), "WAV file should be created"

      WaveFile::Reader.new(path) do |reader|
        assert_equal 2, reader.format.channels
        assert_equal 44_100, reader.format.sample_rate
        assert_operator reader.total_sample_frames, :>, 0
      end
    end
  end

  it "renders the correct number of samples for given cycles" do
    sample_rate = 44_100
    cps = 0.5 # 1 cycle = 2 seconds
    cyclist = Strudel::Scheduler::Cyclist.new(sample_rate: sample_rate, cps: cps)
    pat = @dsl.note("c4").s("sine")
    cyclist.set_pattern(pat)

    renderer = Strudel::Audio::WavRenderer.new(cyclist)

    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.wav")
      renderer.render(cycles: 2, output_path: path)

      # 2 cycles at 0.5 CPS = 4 seconds + 1 second default tail = 5 seconds
      expected_samples = (2.0 / cps * sample_rate).to_i + sample_rate

      WaveFile::Reader.new(path) do |reader|
        # Allow small tolerance for tail
        assert_in_delta expected_samples, reader.total_sample_frames, sample_rate * 0.1
      end
    end
  end

  it "adds tail for reverb/delay decay" do
    sample_rate = 44_100
    cyclist = Strudel::Scheduler::Cyclist.new(sample_rate: sample_rate, cps: 1.0)
    pat = @dsl.note("c4").s("sine")
    cyclist.set_pattern(pat)

    tail_seconds = 2.0
    renderer = Strudel::Audio::WavRenderer.new(cyclist, tail_seconds: tail_seconds)

    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.wav")
      renderer.render(cycles: 1, output_path: path)

      # 1 cycle at 1.0 CPS = 1 second + 2 second tail = 3 seconds
      expected_min = sample_rate * 3

      WaveFile::Reader.new(path) do |reader|
        assert_operator reader.total_sample_frames, :>=, expected_min
      end
    end
  end
end
