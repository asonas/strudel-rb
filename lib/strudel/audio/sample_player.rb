# frozen_string_literal: true

module Strudel
  module Audio
    class SamplePlayer
      attr_reader :playing

      def initialize(sample_data, target_sample_rate = 44_100)
        @sample_data = sample_data
        @target_sample_rate = target_sample_rate
        @position = 0.0
        @playing = false
        @gain = 1.0

        # サンプルレート変換の比率
        @rate_ratio = sample_data.sample_rate.to_f / target_sample_rate
      end

      # 再生開始
      def trigger(gain: 1.0)
        @position = 0.0
        @playing = true
        @gain = gain
      end

      # 再生停止
      def stop
        @playing = false
      end

      # 再生中かどうか
      def playing?
        @playing
      end

      # オーディオサンプルを生成
      def generate(frame_count)
        return Array.new(frame_count, 0.0) unless @playing
        return Array.new(frame_count, 0.0) if @sample_data.empty?

        samples = @sample_data.samples
        output = Array.new(frame_count, 0.0)

        frame_count.times do |i|
          idx = @position.to_i

          if idx >= samples.length
            @playing = false
            break
          end

          # 線形補間でサンプル値を取得
          frac = @position - idx
          current = samples[idx] || 0.0
          next_sample = samples[idx + 1] || current
          output[i] = (current + (next_sample - current) * frac) * @gain

          @position += @rate_ratio
        end

        output
      end
    end
  end
end
