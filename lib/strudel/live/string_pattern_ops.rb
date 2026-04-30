# frozen_string_literal: true

module Strudel
  module Live
    # Strudel JS allows arithmetic chains on bare double-quoted strings, e.g.
    #   "0 2 4".add("<0 3 4 0>")
    # because its transpiler rewrites `"..."` into `m("...")` (a Pattern). In
    # Ruby we don't have that transpilation step, so we instead expose the
    # same operators directly on String. To keep this monkey patch out of the
    # library and tests, the patch is applied via Ruby::Box inside
    # PatternEvaluator. The module is also useful on its own for tests or
    # callers that opt into the patch explicitly.
    module StringPatternOps
      OPERATORS = %i[add sub mul mod pow].freeze

      OPERATORS.each do |op|
        define_method(op) do |other|
          Strudel::Pattern.reify(self).public_send(op, Strudel::Pattern.reify(other))
        end
      end

      # `div` is omitted because Ruby's String#div is not defined and we want
      # to match Strudel's name, but `String#/` is also not defined so adding
      # it does not collide. Pattern#div exists — define it the same way.
      define_method(:div) do |other|
        Strudel::Pattern.reify(self).div(Strudel::Pattern.reify(other))
      end
    end
  end
end
