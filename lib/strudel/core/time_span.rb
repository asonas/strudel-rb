# frozen_string_literal: true

module Strudel
  class TimeSpan
    attr_reader :begin_time, :end_time

    def initialize(begin_time, end_time)
      @begin_time = begin_time.is_a?(Fraction) ? begin_time : Fraction.new(begin_time)
      @end_time = end_time.is_a?(Fraction) ? end_time : Fraction.new(end_time)
    end

    # 時間の長さ
    def duration
      @end_time - @begin_time
    end

    # 中間点
    def midpoint
      @begin_time + (duration / Fraction.new(2))
    end

    # サイクル境界で分割した配列を返す
    def span_cycles
      return [] if @end_time <= @begin_time

      result = []
      current_begin = @begin_time

      while current_begin < @end_time
        cycle_end = current_begin.next_sam
        current_end = cycle_end < @end_time ? cycle_end : @end_time
        result << TimeSpan.new(current_begin, current_end)
        current_begin = current_end
      end

      result
    end

    # 2つの時間区間の交差部分を返す
    def intersection(other)
      new_begin = [@begin_time, other.begin_time].max
      new_end = [@end_time, other.end_time].min

      return nil if new_begin >= new_end

      TimeSpan.new(new_begin, new_end)
    end

    # サイクル内での位置に正規化
    def cycle_arc
      TimeSpan.new(@begin_time.cycle_pos, @begin_time.cycle_pos + duration)
    end

    # 時間に関数を適用
    def with_time(&block)
      TimeSpan.new(block.call(@begin_time), block.call(@end_time))
    end

    def ==(other)
      return false unless other.is_a?(TimeSpan)

      @begin_time == other.begin_time && @end_time == other.end_time
    end

    def eql?(other)
      self == other
    end

    def hash
      [@begin_time, @end_time].hash
    end

    def inspect
      "TimeSpan(#{@begin_time.value}, #{@end_time.value})"
    end
  end
end
