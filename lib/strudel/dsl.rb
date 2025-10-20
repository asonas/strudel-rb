# frozen_string_literal: true

module Strudel
  module DSL
    # sound("bd hh sd hh") のような記法でパターンを作成
    def sound(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      # 値をサウンド情報に変換
      pattern.with_value do |v|
        case v
        when String
          { s: v, n: 0 }
        when Hash
          v[:s] ? v : { s: v.to_s, n: 0 }
        else
          { s: v.to_s, n: 0 }
        end
      end
    end

    alias_method :s, :sound

    # n("0 1 2 3").sound("jazz") のような記法
    def n(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      pattern.with_value { |v| { n: v.to_i } }
    end

    # note("c4 e4 g4") のような記法
    def note(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      pattern.with_value do |v|
        midi_note = Theory::Note.parse(v)
        { note: midi_note || v }
      end
    end

    # silence (無音)
    def silence
      Pattern.silence
    end

    # stack (並列再生)
    def stack(*patterns)
      Pattern.stack(*patterns)
    end

    # sequence (シーケンス)
    def sequence(*patterns)
      Pattern.sequence(*patterns)
    end

    # fastcat (シーケンスのエイリアス)
    def fastcat(*patterns)
      Pattern.fastcat(*patterns)
    end

    # slowcat (1サイクルに1つ)
    def slowcat(*patterns)
      Pattern.slowcat(*patterns)
    end

    # cat (fastcatのエイリアス)
    def cat(*patterns)
      Pattern.fastcat(*patterns)
    end

    # pure (単一値のパターン)
    def pure(value)
      Pattern.pure(value)
    end

    # gain パターン
    def gain(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      pattern.with_value { |v| v.to_f }
    end

    # speed パターン
    def speed(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      pattern.with_value { |v| v.to_f }
    end

    # pan パターン
    def pan(pattern_string)
      pattern = Mini::Parser.new.parse(pattern_string)
      pattern.with_value { |v| v.to_f }
    end

    # euclid (ユークリッドリズム)
    def euclid(pulses, steps, rotation = 0)
      Pattern.euclid(pulses, steps, rotation)
    end
  end

  # Runerクラス：DSLを使って簡単に再生できるようにする
  class Runner
    include DSL

    def initialize(samples_path: nil, cps: 0.5)
      @samples_path = samples_path
      @cps = cps
      @scheduler = nil
      @vca = nil
    end

    def play(pattern)
      setup_audio unless @vca

      @scheduler.set_pattern(pattern)
      @vca.start unless @vca.running?
    end

    def stop
      @vca&.stop
      @scheduler&.reset
    end

    def cps=(value)
      @cps = value
      @scheduler.cps = value if @scheduler
    end

    def setup_audio
      Audio::VCA.initialize_audio
      @scheduler = Scheduler::Cyclist.new(
        cps: @cps,
        samples_path: @samples_path
      )
      @vca = Audio::VCA.new(@scheduler)
    end

    def cleanup
      @vca&.stop
      @vca&.close
      Audio::VCA.terminate_audio
    end
  end
end
