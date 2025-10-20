# frozen_string_literal: true

module Strudel
  class Pattern
    def initialize(&query)
      @query = query
    end

    # 状態に基づいてHapの配列を返す
    def query(state)
      @query.call(state)
    end

    # 時間範囲でクエリ（便利メソッド）
    def query_arc(begin_time, end_time, controls = {})
      span = TimeSpan.new(begin_time, end_time)
      query(State.new(span, controls))
    end

    # ---- ファクトリメソッド ----

    # 単一値のパターン（毎サイクル1回発生）
    def self.pure(value)
      Pattern.new do |state|
        state.span.span_cycles.map do |subspan|
          whole = subspan.begin_time.whole_cycle
          Hap.new(whole, subspan, value)
        end
      end
    end

    # 無音パターン
    def self.silence
      Pattern.new { |_state| [] }
    end

    # 値をパターンに変換（既にパターンならそのまま）
    def self.reify(value)
      return value if value.is_a?(Pattern)

      pure(value)
    end

    # シーケンス（1サイクル内で全てのパターンを再生）
    def self.fastcat(*items)
      return silence if items.empty?

      slowcat(*items).fast(items.length)
    end

    # シーケンス（fastcatのエイリアス）
    def self.sequence(*items)
      fastcat(*items)
    end

    # 1サイクルに1つずつ再生
    def self.slowcat(*items)
      return silence if items.empty?

      patterns = items.map { |item| reify(item) }
      n = patterns.length

      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          cycle_num = subspan.begin_time.sam.to_i
          pattern_index = cycle_num % n
          patterns[pattern_index].query(state.set_span(subspan))
        end
      end
    end

    # 並列再生（スタック）
    def self.stack(*items)
      return silence if items.empty?

      patterns = items.map { |item| reify(item) }

      Pattern.new do |state|
        patterns.flat_map { |pattern| pattern.query(state) }
      end
    end

    # ユークリッドリズム
    def self.euclid(pulses, steps, rotation = 0)
      return silence if pulses <= 0 || steps <= 0

      # Bjorklundアルゴリズムでビートパターンを生成
      pattern_array = bjorklund(pulses, steps)

      # rotationを適用
      pattern_array = pattern_array.rotate(rotation) if rotation != 0

      # ビートの位置を計算
      step_duration = Rational(1, steps)
      beats = pattern_array.each_with_index.filter_map do |beat, i|
        beat ? i : nil
      end

      # パターンを生成
      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          cycle = subspan.begin_time.sam

          beats.filter_map do |beat_pos|
            whole_begin = cycle + Fraction.new(Rational(beat_pos, steps))
            whole_end = cycle + Fraction.new(Rational(beat_pos + 1, steps))
            whole = TimeSpan.new(whole_begin, whole_end)

            part = whole.intersection(subspan)
            next unless part

            Hap.new(whole, part, true)
          end
        end
      end
    end

    # Bjorklundアルゴリズム（ユークリッドリズム生成）
    def self.bjorklund(pulses, steps)
      return Array.new(steps, false) if pulses == 0
      return Array.new(steps, true) if pulses >= steps

      # 初期パターン: pulses個の[1]と(steps-pulses)個の[0]
      groups = Array.new(pulses) { [true] } + Array.new(steps - pulses) { [false] }

      loop do
        # 末尾のグループと同じグループの数をカウント
        last_group = groups.last
        remainder_count = groups.count { |g| g == last_group }

        # 残りが1つだけ、または全部同じなら終了
        break if remainder_count <= 1 || remainder_count == groups.length

        # 末尾から取り出して先頭のグループに追加
        remainder_count.times do |i|
          break if groups.length <= remainder_count

          tail = groups.pop
          groups[i] = groups[i] + tail
        end
      end

      groups.flatten
    end

    # ---- 変換メソッド ----

    # 速度を上げる
    def fast(factor)
      factor = Fraction.new(factor) unless factor.is_a?(Fraction)

      with_query_time { |t| t * factor }
        .with_hap_time { |t| t / factor }
    end

    # 速度を下げる
    def slow(factor)
      fast(Fraction.new(1) / Fraction.new(factor))
    end

    # 値を変換
    def with_value(&block)
      Pattern.new do |state|
        query(state).map { |hap| hap.with_value(&block) }
      end
    end

    # fmap（with_valueのエイリアス）
    def fmap(&block)
      with_value(&block)
    end

    # Hapをフィルタリング
    def filter_haps(&predicate)
      Pattern.new do |state|
        query(state).select(&predicate)
      end
    end

    # onsetがあるHapのみ
    def onsets_only
      filter_haps(&:has_onset?)
    end

    # クエリ時間を変換
    def with_query_time(&block)
      Pattern.new do |state|
        new_span = state.span.with_time(&block)
        query(state.set_span(new_span))
      end
    end

    # Hapの時間を変換
    def with_hap_time(&block)
      Pattern.new do |state|
        query(state).map do |hap|
          hap.with_span { |span| span.with_time(&block) }
        end
      end
    end

    # サイクル境界でクエリを分割
    def split_queries
      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          query(state.set_span(subspan))
        end
      end
    end

    # ---- 算術メソッド ----

    # パターンの値を加算
    def add(other)
      apply_op(other) { |a, b| a + b }
    end

    # パターンの値を減算
    def sub(other)
      apply_op(other) { |a, b| a - b }
    end

    # パターンの値を乗算
    def mul(other)
      apply_op(other) { |a, b| a * b }
    end

    # パターンの値を除算
    def div(other)
      apply_op(other) { |a, b| a / b }
    end

    # サンプルをサイクルの長さに合わせる
    def fit
      Pattern.new do |state|
        query(state).map do |hap|
          duration = hap.whole ? hap.whole.duration : hap.part.duration
          speed = 1.0 / duration.to_f

          new_value = case hap.value
                      when Hash
                        hap.value.merge(unit: "c", speed: speed)
                      else
                        { s: hap.value, unit: "c", speed: speed }
                      end

          Hap.new(hap.whole, hap.part, new_value, hap.context)
        end
      end
    end

    # n回ごとに関数を適用
    def every(n, &func)
      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          cycle_num = subspan.begin_time.sam.to_i
          pat = (cycle_num % n == n - 1) ? func.call(self) : self
          pat.query(state.set_span(subspan))
        end
      end
    end

    # パターンを逆再生
    def rev
      split_queries.then do |pat|
        Pattern.new do |state|
          span = state.span
          cycle = span.begin_time.sam

          # サイクル内での位置を反転する関数
          reflect_in_cycle = lambda do |t, base_cycle|
            pos = t.value - base_cycle.value
            # 1を超える場合（次のサイクル）は調整
            pos = 1 if pos == 0 && t != base_cycle
            Fraction.new(base_cycle.value + (1 - pos))
          end

          # 反転した範囲を計算
          reflected_begin = reflect_in_cycle.call(span.end_time, cycle)
          reflected_end = reflect_in_cycle.call(span.begin_time, cycle)
          reflected_span = TimeSpan.new(reflected_begin, reflected_end)

          # 反転した範囲でクエリ
          haps = pat.query(state.set_span(reflected_span))

          # 結果のhapsの時間を反転
          haps.map do |hap|
            hap_cycle = hap.whole&.begin_time&.sam || hap.part.begin_time.sam

            new_whole = hap.whole && begin
              w_begin = reflect_in_cycle.call(hap.whole.end_time, hap_cycle)
              w_end = reflect_in_cycle.call(hap.whole.begin_time, hap_cycle)
              TimeSpan.new(w_begin, w_end)
            end

            p_begin = reflect_in_cycle.call(hap.part.end_time, hap_cycle)
            p_end = reflect_in_cycle.call(hap.part.begin_time, hap_cycle)
            new_part = TimeSpan.new(p_begin, p_end)

            Hap.new(new_whole, new_part, hap.value, hap.context)
          end.sort_by { |h| h.part.begin_time.value }
        end
      end
    end

    # ノートを移調（セミトーン単位）
    def trans(semitones)
      semitones_pattern = self.class.reify(semitones)

      Pattern.new do |state|
        query(state).flat_map do |hap|
          query_span = hap.whole || hap.part
          semitone_haps = semitones_pattern.query(state.set_span(query_span))

          semitone_haps.filter_map do |semitone_hap|
            intersection = hap.part.intersection(semitone_hap.part)
            next unless intersection

            new_whole = if hap.whole && semitone_hap.whole
                          hap.whole.intersection(semitone_hap.whole)
                        end

            new_value = if hap.value.is_a?(Hash) && hap.value[:note]
                          hap.value.merge(note: hap.value[:note] + semitone_hap.value)
                        else
                          hap.value
                        end

            Hap.new(new_whole, intersection, new_value)
          end
        end
      end
    end

    # スケール度数をノートに変換
    def scale(scale_spec)
      root, scale_name = Theory::Scale.parse_scale_name(scale_spec)
      base_note = 60 + root # C4 = 60 + root offset

      with_value do |degree|
        semitone = Theory::Scale.degree_to_semitone(degree, scale_name)
        { note: base_note + semitone }
      end
    end

    # ---- コントロールメソッド ----

    # 音量を設定 (0.0 - 1.0)
    def gain(value)
      set_control(:gain, value)
    end

    # パンを設定 (0.0 = 左, 0.5 = 中央, 1.0 = 右)
    def pan(value)
      set_control(:pan, value)
    end

    # 再生速度を設定
    def speed(value)
      set_control(:speed, value)
    end

    # ローパスフィルターのカットオフ周波数を設定
    def lpf(value)
      set_control(:lpf, value)
    end

    # ハイパスフィルターのカットオフ周波数を設定
    def hpf(value)
      set_control(:hpf, value)
    end

    def inspect
      "Pattern"
    end

    private

    # コントロール値を設定（inner join方式でパターン対応）
    def set_control(key, value)
      value_pattern = self.class.reify(value)

      Pattern.new do |state|
        query(state).flat_map do |hap|
          query_span = hap.whole || hap.part
          value_haps = value_pattern.query(state.set_span(query_span))

          value_haps.filter_map do |value_hap|
            intersection = hap.part.intersection(value_hap.part)
            next unless intersection

            new_whole = if hap.whole && value_hap.whole
                          hap.whole.intersection(value_hap.whole)
                        end

            new_value = hap.value.is_a?(Hash) ? hap.value.merge(key => value_hap.value) : { key => value_hap.value }
            Hap.new(new_whole, intersection, new_value)
          end
        end
      end
    end

    # 二項演算を適用（inner join方式）
    def apply_op(other, &block)
      other_pattern = self.class.reify(other)

      Pattern.new do |state|
        query(state).flat_map do |hap_left|
          # 左のHapのwholeの時間範囲で右のパターンをクエリ
          query_span = hap_left.whole || hap_left.part
          right_haps = other_pattern.query(state.set_span(query_span))

          right_haps.filter_map do |hap_right|
            # 2つのHapの時間範囲が重なる部分を計算
            intersection = hap_left.part.intersection(hap_right.part)
            next unless intersection

            # 新しいwhole（両方のwholeの交差）
            new_whole = if hap_left.whole && hap_right.whole
                          hap_left.whole.intersection(hap_right.whole)
                        end

            # 値を演算で結合
            new_value = block.call(hap_left.value, hap_right.value)
            Hap.new(new_whole, intersection, new_value)
          end
        end
      end
    end
  end
end
