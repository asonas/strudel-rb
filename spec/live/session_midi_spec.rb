# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Live::Session do
  describe "#stop" do
    it "stops all registered MIDI inputs" do
      Strudel::Midi::Registry.reset!
      input = Strudel::Midi::Registry.open("fake-device", open_device: false)
      stopped = false
      input.define_singleton_method(:stop) { stopped = true }

      session = Strudel::Live::Session.new
      session.stop

      assert stopped
    end
  end
end
