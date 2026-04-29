# frozen_string_literal: true

# MIDI CC helpers (extracted from pattern.rb).
#
# Adds `on_cc` and `accumulator_entry` to `Strudel::Midi::Input`, and provides
# `relative_cc` so that relative-mode CC encoders (127 = increment, 1 = decrement)
# can be exposed as a `Pattern.ref`.

::Strudel::Midi::Input.class_eval do
  unless method_defined?(:on_cc)
    alias_method :_original_record_cc, :record_cc

    def record_cc(cc_num, channel, raw_value)
      _original_record_cc(cc_num, channel, raw_value)
      (@listeners ||= {}).each do |(cc, ch), callback|
        next unless cc == cc_num
        next if ch && ch != channel
        callback.call(raw_value, channel)
      end
    end

    def on_cc(cc_num, channel: nil, &block)
      (@listeners ||= {})[[cc_num, channel]] = block
    end

    def accumulator_entry(cc_num, channel, initial)
      @accumulators ||= {}
      @accumulators[[cc_num, channel]] ||= { value: initial, mutex: Mutex.new }
    end
  end
end

def relative_cc(input, cc_num, step: 0.05, initial: 0.5, min: 0.0, max: 1.0, channel: nil)
  entry = input.accumulator_entry(cc_num, channel, initial)
  mutex = entry[:mutex]

  input.on_cc(cc_num, channel: channel) do |raw, _ch|
    mutex.synchronize do
      if raw == 127
        entry[:value] = [entry[:value] + step, max].min
      elsif raw == 1
        entry[:value] = [entry[:value] - step, min].max
      end
    end
  end

  ::Strudel::Pattern.ref { mutex.synchronize { entry[:value] } }
end
