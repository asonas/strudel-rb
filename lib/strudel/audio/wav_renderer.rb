# frozen_string_literal: true

require "wavefile"

module Strudel
  module Audio
    class WavRenderer
      CHUNK_SIZE = 128

      def initialize(cyclist, tail_seconds: 1.0)
        @cyclist = cyclist
        @tail_seconds = tail_seconds
      end

      def render(cycles:, output_path:)
        sample_rate = @cyclist.sample_rate
        cps = @cyclist.cps
        cps_f = cps.is_a?(Rational) ? cps.to_f : cps

        total_seconds = cycles / cps_f
        tail_samples = (@tail_seconds * sample_rate).to_i
        total_samples = (total_seconds * sample_rate).to_i + tail_samples

        main_samples = (total_seconds * sample_rate).to_i

        left_all = []
        right_all = []
        rendered = 0

        while rendered < total_samples
          # テール区間に入ったらパターンを消して残響のみ録音
          if rendered >= main_samples && @cyclist.pattern
            @cyclist.set_pattern(nil)
          end

          chunk = [CHUNK_SIZE, total_samples - rendered].min
          left, right = @cyclist.generate(chunk)
          left_all.concat(left)
          right_all.concat(right)
          rendered += chunk

          if rendered % (sample_rate / 2) < CHUNK_SIZE
            progress = (rendered.to_f / total_samples * 100).to_i
            warn "Recording... #{progress}%"
          end
        end

        write_wav(output_path, left_all, right_all, sample_rate)
        warn "Saved: #{output_path} (#{total_samples.to_f / sample_rate} sec)"
      end

      private

      def write_wav(path, left, right, sample_rate)
        output_format = WaveFile::Format.new(:stereo, :pcm_16, sample_rate)
        source_format = WaveFile::Format.new(:stereo, :float, sample_rate)
        interleaved = left.zip(right).map { |l, r| [clamp(l), clamp(r)] }

        WaveFile::Writer.new(path, output_format) do |writer|
          interleaved.each_slice(4096) do |chunk|
            buffer = WaveFile::Buffer.new(chunk, source_format)
            writer.write(buffer)
          end
        end
      end

      def clamp(sample)
        sample.clamp(-1.0, 1.0)
      end
    end
  end
end
