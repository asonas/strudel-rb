# frozen_string_literal: true

require "listen"

module Strudel
  module Live
    class FileWatcher
      def initialize(path)
        @path = File.expand_path(path)
        @dir = File.dirname(@path)
        @filename = File.basename(@path)
        @callbacks = []
        @listener = nil
      end

      def on_change(&block)
        @callbacks << block
      end

      def start
        @listener = Listen.to(@dir, only: /#{Regexp.escape(@filename)}$/) do |modified, added, _removed|
          if modified.include?(@path) || added.include?(@path)
            @callbacks.each { |cb| cb.call(@path) }
          end
        end
        @listener.start
      end

      def stop
        @listener&.stop
      end
    end
  end
end
