# frozen_string_literal: true

require_relative "strudel/core/fraction"
require_relative "strudel/core/time_span"
require_relative "strudel/core/hap"
require_relative "strudel/core/state"
require_relative "strudel/core/pattern"
require_relative "strudel/mini/parser"
require_relative "strudel/audio/sample_bank"
require_relative "strudel/audio/sample_player"
require_relative "strudel/audio/oscillator"
require_relative "strudel/audio/filter"
require_relative "strudel/audio/synth_player"
require_relative "strudel/audio/vca"
require_relative "strudel/scheduler/cyclist"
require_relative "strudel/theory/note"
require_relative "strudel/theory/scale"
require_relative "strudel/dsl"
require_relative "strudel/live/pattern_evaluator"
require_relative "strudel/live/file_watcher"
require_relative "strudel/live/session"

module Strudel
  VERSION = "0.1.0"
end
