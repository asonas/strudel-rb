# frozen_string_literal: true

require_relative "spec_helper"

describe Strudel::DSL do
  include Strudel::DSL

  before do
    Strudel::Midi::Registry.reset!
  end

  describe "#midi_input" do
    it "returns a Midi::Input keyed by device name" do
      input = midi_input("virtual-device", open_device: false)

      assert_instance_of Strudel::Midi::Input, input
      assert_equal "virtual-device", input.device_name
    end

    it "returns the same input on repeated calls (via Registry)" do
      a = midi_input("virtual-device", open_device: false)
      b = midi_input("virtual-device", open_device: false)

      assert_same a, b
    end

    it "lets patterns consume CC values via #cc" do
      input = midi_input("virtual-device", open_device: false)
      input.record_cc(7, 1, 127)

      pat = input.cc(7).range(0, 100)
      haps = pat.query_arc(0, 1)

      assert_in_delta 100.0, haps.first.value, 0.0001
    end
  end
end
