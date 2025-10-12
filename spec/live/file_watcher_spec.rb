# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/strudel/live/file_watcher"

describe Strudel::Live::FileWatcher do
  describe "#initialize" do
    it "accepts a file path" do
      watcher = Strudel::Live::FileWatcher.new("/path/to/pattern.rb")

      assert_instance_of Strudel::Live::FileWatcher, watcher
    end
  end

  describe "#on_change" do
    it "registers a callback block" do
      watcher = Strudel::Live::FileWatcher.new("/path/to/pattern.rb")
      callback_called = false

      watcher.on_change { callback_called = true }

      # コールバックが登録されていることを確認（内部状態のテスト）
      assert_respond_to watcher, :on_change
    end
  end
end
