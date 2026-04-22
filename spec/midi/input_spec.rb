# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Midi::Input do
  describe "#cc" do
    it "returns 0.0 when no CC has been received" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      pattern = input.cc(7)

      haps = pattern.query_arc(0, 1)
      assert_equal 0.0, haps.first.value
    end

    it "returns the latest CC value normalized to 0.0..1.0" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      input.record_cc(7, 1, 127)

      haps = input.cc(7).query_arc(0, 1)
      assert_in_delta 1.0, haps.first.value, 0.0001
    end

    it "normalizes midpoint CC to ~0.5" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      input.record_cc(7, 1, 64)

      haps = input.cc(7).query_arc(0, 1)
      assert_in_delta 64.0 / 127.0, haps.first.value, 0.0001
    end

    it "reflects later updates on subsequent queries (Pattern.ref semantics)" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      pattern = input.cc(7)

      input.record_cc(7, 1, 0)
      assert_in_delta 0.0, pattern.query_arc(0, 1).first.value, 0.0001

      input.record_cc(7, 1, 127)
      assert_in_delta 1.0, pattern.query_arc(1, 2).first.value, 0.0001
    end

    it "filters by channel when chan is given" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      input.record_cc(7, 1, 127)
      input.record_cc(7, 2, 0)

      ch1 = input.cc(7, 1).query_arc(0, 1).first.value
      ch2 = input.cc(7, 2).query_arc(0, 1).first.value

      assert_in_delta 1.0, ch1, 0.0001
      assert_in_delta 0.0, ch2, 0.0001
    end

    it "is thread-safe for concurrent writes and reads" do
      input = Strudel::Midi::Input.new(device_name: "test", open_device: false)
      pattern = input.cc(7)

      writer = Thread.new do
        1000.times { |i| input.record_cc(7, 1, i % 128) }
      end
      reader = Thread.new do
        1000.times { pattern.query_arc(0, 1) }
      end

      [writer, reader].each(&:join)
      # if no exception was raised, the mutex is working
      assert true
    end
  end
end
