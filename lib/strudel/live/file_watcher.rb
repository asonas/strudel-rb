# frozen_string_literal: true

begin
  require "listen"
rescue LoadError
  # Optional dependency for live file watching.
  # If `listen` can't be loaded in the current environment, we'll raise a clearer
  # error when `#start` is called.
end

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
        unless defined?(Listen)
          raise LoadError,
                'The "listen" gem is required to use Strudel::Live::FileWatcher. ' \
                'Please add `gem "listen"` and run `bundle install`.'
        end

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
