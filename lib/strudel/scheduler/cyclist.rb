# frozen_string_literal: true

module Strudel
  module Scheduler
    class Cyclist
      attr_accessor :cps, :pattern
      attr_reader :sample_rate

      DEFAULT_CPS = 0.5 # cycles per second (1サイクル = 2秒)
      DEFAULT_SAMPLE_RATE = 44_100
      SYNTH_WAVEFORMS = %w[sine sawtooth square triangle].freeze

      def initialize(sample_rate: DEFAULT_SAMPLE_RATE, cps: DEFAULT_CPS, samples_path: nil)
        @sample_rate = sample_rate
        @cps = cps
        @pattern = nil
        @sample_bank = Audio::SampleBank.new(samples_path)
        @active_players = []
        @current_cycle = Fraction.new(0)
        @mutex = Mutex.new
      end

      # パターンを設定
      def set_pattern(pattern)
        @mutex.synchronize do
          @pattern = pattern
        end
      end

      # オーディオフレームを生成（VCAから呼ばれる）
      def generate(frame_count)
        @mutex.synchronize do
          # フレーム数をサイクル数に変換
          frames_per_cycle = @sample_rate / @cps
          duration_in_cycles = Fraction.new(Rational(frame_count, frames_per_cycle.to_i))

          end_cycle = @current_cycle + duration_in_cycles

          # パターンをクエリしてHapを取得
          if @pattern
            begin
              haps = @pattern.query_arc(@current_cycle.value, end_cycle.value)

              # onsetがあるHapの音をトリガー
              haps.select(&:has_onset?).each do |hap|
                trigger_sound(hap)
              end
            rescue StandardError => e
              warn "Error querying pattern: #{e.message}"
            end
          end

          # アクティブなプレイヤーからサンプルを生成してミックス
          samples = mix_players(frame_count)

          # 終了したプレイヤーを削除
          @active_players.reject! { |p| !p.playing? }

          @current_cycle = end_cycle
          samples
        end
      end

      # サイクル位置をリセット
      def reset
        @mutex.synchronize do
          @current_cycle = Fraction.new(0)
          @active_players.clear
        end
      end

      private

      def trigger_sound(hap)
        value = hap.value

        # 値からサウンド名とサンプル番号を抽出
        sound_name, sample_n = extract_sound_info(value)
        return unless sound_name

        gain = extract_gain(value)

        # シンセの場合
        if SYNTH_WAVEFORMS.include?(sound_name)
          player = Audio::SynthPlayer.new(
            sound_name.to_sym,
            sample_rate: @sample_rate,
            gain: gain
          )
          note = extract_note(value)
          player.trigger(note: note)
          @active_players << player
          return
        end

        # サンプルの場合
        sample_data = @sample_bank.get(sound_name, sample_n)
        return if sample_data.empty?

        speed = extract_speed(value)
        player = Audio::SamplePlayer.new(sample_data, @sample_rate)
        player.trigger(gain: gain, speed: speed)
        @active_players << player
      end

      def extract_sound_info(value)
        case value
        when String
          [value, 0]
        when Hash
          name = value[:s] || value[:sound]
          n = value[:n] || 0
          [name, n]
        else
          [nil, 0]
        end
      end

      def extract_gain(value)
        return 1.0 unless value.is_a?(Hash)

        value[:gain] || value[:velocity]&./(127.0) || 1.0
      end

      def extract_note(value)
        return 60 unless value.is_a?(Hash) # Default: C4

        value[:note] || value[:n] || 60
      end

      def extract_speed(value)
        return 1.0 unless value.is_a?(Hash)

        value[:speed] || 1.0
      end

      def mix_players(frame_count)
        return Array.new(frame_count, 0.0) if @active_players.empty?

        # 各プレイヤーからサンプルを取得
        player_outputs = @active_players.map { |p| p.generate(frame_count) }

        # ミックス
        mixed = Array.new(frame_count, 0.0)
        player_outputs.each do |output|
          frame_count.times do |i|
            mixed[i] += output[i]
          end
        end

        # ゲイン調整（同時発音数に応じて）
        active_count = @active_players.count(&:playing?)
        if active_count > 1
          gain = 1.0 / Math.sqrt(active_count)
          mixed.map! { |s| s * gain }
        end

        mixed
      end
    end
  end
end
