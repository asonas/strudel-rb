# frozen_string_literal: true

require "unimidi"

module Strudel
  module Midi
    # Wraps a single MIDI input device. Owns a background reader thread that
    # keeps an internal store of the latest CC value per (cc_number, channel).
    # Exposes `cc(num, chan=nil)` returning a Pattern whose query-time value
    # is the most recently received CC value (normalized to 0.0..1.0).
    #
    # Thread model: the reader thread is the only writer. Pattern queries
    # (audio/scheduler threads) are readers. A Mutex protects all access.
    class Input
      STATUS_CC = 0xB0

      attr_reader :device_name

      def initialize(device_name:, open_device: true)
        @device_name = device_name
        @mutex = Mutex.new
        @values = Hash.new(0.0)             # {cc_num => normalized_value}
        @values_by_channel = {}             # {chan => {cc_num => normalized_value}}
        @reader_thread = nil
        @stopping = false
        open if open_device
      end

      # Inject a CC value (used by reader thread and tests). raw_value is 0..127.
      def record_cc(cc_num, channel, raw_value)
        scaled = raw_value.to_f / 127.0
        @mutex.synchronize do
          @values[cc_num] = scaled
          @values_by_channel[channel] ||= Hash.new(0.0)
          @values_by_channel[channel][cc_num] = scaled
        end
      end

      # Returns a Pattern that, on query, yields the latest CC value.
      # If chan is nil, returns the most recent value regardless of channel.
      def cc(cc_num, chan = nil)
        Strudel::Pattern.ref { current_value(cc_num, chan) }
      end

      def stop
        @stopping = true
        @reader_thread&.join(1)
        @device&.close
      end

      private

      def current_value(cc_num, chan)
        @mutex.synchronize do
          if chan.nil?
            @values[cc_num]
          else
            (@values_by_channel[chan] ||= Hash.new(0.0))[cc_num]
          end
        end
      end

      def open
        @device = find_device(@device_name)
        unless @device
          warn "[midi] device not found: #{@device_name}"
          return
        end
        @device.open
        start_reader
      end

      def find_device(name)
        UniMIDI::Input.all.find { |d| d.name == name }
      end

      def start_reader
        @reader_thread = Thread.new do
          until @stopping
            messages = @device.gets
            next if messages.nil? || messages.empty?

            messages.each { |msg| handle_message(msg) }
          end
        rescue StandardError => e
          warn "[midi] reader thread error: #{e.class}: #{e.message}"
        end
      end

      def handle_message(msg)
        data = msg[:data]
        return unless data && data.length >= 3

        status = data[0]
        return unless (status & 0xF0) == STATUS_CC

        channel = (status & 0x0F) + 1  # 1..16
        cc_num  = data[1]
        value   = data[2]
        record_cc(cc_num, channel, value)
      end
    end
  end
end
