# frozen_string_literal: true

# Generate test fixture WAV files for SampleBank specs
# Usage: bundle exec ruby spec/fixtures/generate_fixtures.rb

require "wavefile"

FIXTURES_DIR = File.expand_path("samples", __dir__)

def generate_sine_wav(path, frequency: 440.0, duration: 0.1, sample_rate: 44_100)
  num_samples = (sample_rate * duration).to_i
  samples = Array.new(num_samples) do |i|
    (Math.sin(2.0 * Math::PI * frequency * i / sample_rate) * 32_000).to_i
  end

  format = WaveFile::Format.new(:mono, :pcm_16, sample_rate)
  buffer = WaveFile::Buffer.new(samples, format)

  WaveFile::Writer.new(path, format) do |writer|
    writer.write(buffer)
  end
end

# pitched_test: 2 WAV files + pitch.json
pitched_dir = File.join(FIXTURES_DIR, "pitched_test")
generate_sine_wav(File.join(pitched_dir, "0.wav"), frequency: 261.63) # C4
generate_sine_wav(File.join(pitched_dir, "1.wav"), frequency: 523.25) # C5

File.write(File.join(pitched_dir, "pitch.json"), '{"0": 60, "1": 72}')

# unpitched_test: 1 WAV file, no pitch.json
unpitched_dir = File.join(FIXTURES_DIR, "unpitched_test")
generate_sine_wav(File.join(unpitched_dir, "0.wav"), frequency: 440.0) # A4

puts "Fixtures generated successfully."
puts "  #{pitched_dir}/0.wav (C4 sine)"
puts "  #{pitched_dir}/1.wav (C5 sine)"
puts "  #{pitched_dir}/pitch.json"
puts "  #{unpitched_dir}/0.wav (A4 sine)"
