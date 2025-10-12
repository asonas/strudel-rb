# frozen_string_literal: true

module Strudel
  class Hap
    attr_reader :whole, :part, :value, :context

    def initialize(whole, part, value, context = {})
      @whole = whole
      @part = part
      @value = value
      @context = context
    end

    # イベントの開始点かどうか（part.beginがwhole.beginと一致）
    def has_onset?
      return false if @whole.nil?

      @whole.begin_time == @part.begin_time
    end

    # 値を変換した新しいHapを返す
    def with_value(&block)
      Hap.new(@whole, @part, block.call(@value), @context)
    end

    # 時間区間を変換した新しいHapを返す
    def with_span(&block)
      new_whole = @whole ? block.call(@whole) : nil
      new_part = block.call(@part)
      Hap.new(new_whole, new_part, @value, @context)
    end

    # イベントの長さ
    def duration
      (@whole || @part).duration
    end

    # partでの長さ
    def part_duration
      @part.duration
    end

    def ==(other)
      return false unless other.is_a?(Hap)

      @whole == other.whole &&
        @part == other.part &&
        @value == other.value
    end

    def eql?(other)
      self == other
    end

    def hash
      [@whole, @part, @value].hash
    end

    def inspect
      "Hap(whole: #{@whole&.inspect}, part: #{@part.inspect}, value: #{@value.inspect})"
    end
  end
end
