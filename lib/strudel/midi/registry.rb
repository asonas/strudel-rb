# frozen_string_literal: true

module Strudel
  module Midi
    # Process-wide registry of MIDI Input instances, keyed by device name.
    # Ensures that re-evaluation of pattern.rb does not re-open devices.
    module Registry
      @mutex = Mutex.new
      @inputs = {}

      class << self
        attr_reader :inputs

        def open(device_name, open_device: true)
          @mutex.synchronize do
            @inputs[device_name] ||= Input.new(
              device_name: device_name,
              open_device: open_device
            )
          end
        end

        def stop_all
          @mutex.synchronize do
            @inputs.each_value(&:stop)
            @inputs.clear
          end
        end

        # For tests.
        def reset!
          @mutex.synchronize do
            @inputs.each_value { |i| i.stop rescue nil }
            @inputs.clear
          end
        end
      end
    end
  end
end
