# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Midi::Registry do
  before do
    Strudel::Midi::Registry.reset!
  end

  describe ".open" do
    it "returns the same instance for the same device name" do
      a = Strudel::Midi::Registry.open("test-device", open_device: false)
      b = Strudel::Midi::Registry.open("test-device", open_device: false)

      assert_same a, b
    end

    it "returns distinct instances for different names" do
      a = Strudel::Midi::Registry.open("dev-1", open_device: false)
      b = Strudel::Midi::Registry.open("dev-2", open_device: false)

      refute_same a, b
    end
  end

  describe ".stop_all" do
    it "stops every registered input and clears the registry" do
      a = Strudel::Midi::Registry.open("dev-1", open_device: false)
      stopped = false
      a.define_singleton_method(:stop) { stopped = true }

      Strudel::Midi::Registry.stop_all

      assert stopped
      assert_empty Strudel::Midi::Registry.inputs
    end
  end
end
