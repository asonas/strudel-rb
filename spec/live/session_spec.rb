# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/strudel/live/pattern_evaluator"
require_relative "../../lib/strudel/live/file_watcher"
require_relative "../../lib/strudel/live/session"
require "tempfile"

describe Strudel::Live::Session do
  describe "#initialize" do
    it "creates a session instance" do
      session = Strudel::Live::Session.new

      assert_instance_of Strudel::Live::Session, session
    end
  end

  describe "#load_pattern" do
    it "loads and returns a pattern from file" do
      session = Strudel::Live::Session.new

      file = Tempfile.new(["pattern", ".rb"])
      file.write('sound("bd hh sd hh")')
      file.close

      pattern = session.load_pattern(file.path)

      assert_instance_of Strudel::Pattern, pattern
    ensure
      file&.unlink
    end

    it "returns nil and prints error on syntax error" do
      session = Strudel::Live::Session.new

      file = Tempfile.new(["pattern", ".rb"])
      file.write('sound("bd"')
      file.close

      result = session.load_pattern(file.path)

      assert_nil result
    ensure
      file&.unlink
    end

    it "returns nil and prints error on parse error" do
      session = Strudel::Live::Session.new

      file = Tempfile.new(["pattern", ".rb"])
      file.write('sound("[[[[")')
      file.close

      result = session.load_pattern(file.path)

      assert_nil result
    ensure
      file&.unlink
    end
  end
end
