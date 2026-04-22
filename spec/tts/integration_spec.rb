# frozen_string_literal: true

require_relative "../spec_helper"

describe "Strudel TTS integration" do
  it "exposes Strudel.tts_generator as a default Generator" do
    assert_instance_of Strudel::TTS::Generator, Strudel.tts_generator
  end

  it "includes SayEngine in the default generator" do
    engines = Strudel.tts_generator.instance_variable_get(:@engines)
    assert engines.any? { |e| e.is_a?(Strudel::TTS::SayEngine) }
  end

  it "allows swapping tts_generator for testing" do
    original = Strudel.tts_generator
    Strudel.tts_generator = :custom
    assert_equal :custom, Strudel.tts_generator
  ensure
    Strudel.tts_generator = original
  end
end
