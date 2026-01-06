# frozen_string_literal: true

# See: https://tidalcycles.org/docs/reference/mini_notation/
require "parslet"

module Strudel
  module Mini
    # Mini-Notation grammar parser
    class Grammar < Parslet::Parser
      # Whitespace
      rule(:space) { match('\s').repeat(1) }
      rule(:space?) { space.maybe }

      # Atom (sound name, note name including sharps/flats)
      rule(:atom_char) { match('[a-zA-Z0-9_#]') }
      rule(:atom_name) { atom_char.repeat(1).as(:name) }

      # Sample number (:n)
      rule(:sample_number) { str(":") >> match('[0-9]').repeat(1).as(:n) }

      # Atom (name + optional sample number)
      rule(:atom) do
        (atom_name >> sample_number.maybe).as(:atom)
      end

      # Rest
      rule(:rest) { (str("~") | str("-")).as(:rest) }

      # Elongate (extends previous event by one step)
      rule(:elongate) { str("_").as(:elongate) }

      # Multiplier (*n)
      rule(:multiplier) { str("*") >> match('[0-9.]').repeat(1).as(:mult) }

      # Replicate (!n)
      rule(:replicate) { str("!") >> match('[0-9.]').repeat(1).as(:rep) }

      # Basic element (atom, rest, elongate, or group)
      rule(:element) do
        (
          (elongate | rest | atom | group | angle_group) >> (replicate | multiplier).maybe
        ).as(:element)
      end

      # Square bracket group [...]
      rule(:group) do
        str("[") >> space? >> pattern >> space? >> str("]")
      end

      # Angle bracket group <...> (slowcat)
      rule(:angle_group) do
        (str("<") >> space? >> sequence >> space? >> str(">")).as(:slowcat)
      end

      # Sequence (space-separated)
      rule(:sequence) do
        (element >> (space >> element).repeat).as(:sequence)
      end

      # Stack (comma-separated)
      rule(:stack) do
        (sequence >> (space? >> str(",") >> space? >> sequence).repeat(1)).as(:stack)
      end

      # Pattern (stack or sequence)
      rule(:pattern) do
        stack | sequence
      end

      # Root
      root(:pattern)
    end

    # AST transformer
    class Transform < Parslet::Transform
      # Rest
      rule(rest: simple(:_)) { nil }

      # Elongate token
      rule(elongate: simple(:_)) { :_elongate }

      # Atom (name only)
      rule(atom: { name: simple(:name) }) do
        name.to_s
      end

      # Atom (name + sample number)
      rule(atom: { name: simple(:name), n: simple(:n) }) do
        { s: name.to_s, n: n.to_s.to_i }
      end

      # Element (with multiplier)
      rule(element: { atom: subtree(:atom_content), mult: simple(:mult) }) { { atom: atom_content, mult: mult.to_s.to_f } }
      # Normalize slowcat payload when combined with multiplier/replicate.
      # Without this, slowcat stays as { sequence: [...] } and is treated like a sequence-in-cycle.
      rule(element: { slowcat: { sequence: subtree(:items) }, mult: simple(:mult) }) do
        { slowcat: items.is_a?(Array) ? items : [items], mult: mult.to_s.to_f }
      end
      rule(element: { slowcat: subtree(:cat), mult: simple(:mult) }) { { slowcat: cat, mult: mult.to_s.to_f } }
      rule(element: { sequence: subtree(:seq), mult: simple(:mult) }) { { sequence: seq, mult: mult.to_s.to_f } }
      rule(element: { stack: subtree(:items), mult: simple(:mult) }) { { stack: items, mult: mult.to_s.to_f } }

      # Element (with replicate)
      rule(element: { atom: subtree(:atom_content), rep: simple(:rep) }) { { atom: atom_content, rep: rep.to_s.to_i } }
      rule(element: { slowcat: { sequence: subtree(:items) }, rep: simple(:rep) }) do
        { slowcat: items.is_a?(Array) ? items : [items], rep: rep.to_s.to_i }
      end
      rule(element: { slowcat: subtree(:cat), rep: simple(:rep) }) { { slowcat: cat, rep: rep.to_s.to_i } }
      rule(element: { sequence: subtree(:seq), rep: simple(:rep) }) { { sequence: seq, rep: rep.to_s.to_i } }
      rule(element: { stack: subtree(:items), rep: simple(:rep) }) { { stack: items, rep: rep.to_s.to_i } }

      rule(element: { rest: simple(:_), mult: simple(:mult) }) do
        { rest: nil, mult: mult.to_s.to_f }
      end

      rule(element: { sequence: subtree(:seq), mult: simple(:mult) }) do
        { sequence: seq, mult: mult.to_s.to_f }
      end

      rule(element: { slowcat: subtree(:cat) }) do
        { slowcat: cat }
      end

      # Element (without multiplier/replicate)
      rule(element: subtree(:content)) do
        content
      end

      # Sequence
      rule(sequence: subtree(:items)) do
        items.is_a?(Array) ? { sequence: items } : items
      end

      # Stack
      rule(stack: subtree(:items)) do
        { stack: items.is_a?(Array) ? items : [items] }
      end

      # Slowcat
      rule(slowcat: { sequence: subtree(:items) }, mult: simple(:mult)) do
        { slowcat: items.is_a?(Array) ? items : [items], mult: mult.to_s.to_f }
      end
      rule(slowcat: { sequence: subtree(:items) }, rep: simple(:rep)) do
        { slowcat: items.is_a?(Array) ? items : [items], rep: rep.to_s.to_i }
      end
      rule(slowcat: { sequence: subtree(:items) }) do
        { slowcat: items.is_a?(Array) ? items : [items] }
      end
    end

    # Parser implementation
    class Parser
      Event = Data.define(:start_pos, :end_pos, :value)

      def initialize
        @grammar = Grammar.new
        @transform = Transform.new
      end

      def parse(input)
        tree = @grammar.parse(input.strip)
        ast = @transform.apply(tree)
        ast_to_pattern(ast)
      rescue Parslet::ParseFailed => e
        raise "Parse error: #{e.message}"
      end

      private

      def build_events_fn(ast)
        case ast
        when String
          ->(_cycle_index) { [Event.new(Rational(0, 1), Rational(1, 1), ast)] }
        when NilClass
          ->(_cycle_index) { [] }
        when Symbol
          # :_elongate token (handled by sequence)
          ->(_cycle_index) { [] }
        when Array
          build_events_fn(sequence: ast)
        when Hash
          if ast[:rep]
            rep = ast[:rep].to_i
            rep = 1 if rep <= 0
            base = ast.dup
            base.delete(:rep)
            return build_events_fn(sequence: Array.new(rep, base))
          end

          if ast[:s]
            return ->(_cycle_index) { [Event.new(Rational(0, 1), Rational(1, 1), ast)] }
          end

          if ast[:sequence]
            items = ast[:sequence].is_a?(Array) ? ast[:sequence] : [ast[:sequence]]
            steps = items.flat_map { |it| expand_replicate_step(it) }
            fn = steps_to_events_fn(steps)
            ast[:mult] ? multiply_events_fn(fn, ast[:mult]) : fn
          elsif ast[:stack]
            items = ast[:stack].is_a?(Array) ? ast[:stack] : [ast[:stack]]
            fns = items.map { |it| build_events_fn(it) }
            fn = ->(cycle_index) { fns.flat_map { |f| f.call(cycle_index) } }
            ast[:mult] ? multiply_events_fn(fn, ast[:mult]) : fn
          elsif ast[:slowcat]
            items = ast[:slowcat].is_a?(Array) ? ast[:slowcat] : [ast[:slowcat]]
            fns = items.map { |it| build_events_fn(it) }
            n = fns.length

            # In Tidal mini-notation, "_" elongates/holds the previous event.
            # For slowcat (<...>), that means "repeat the previous cycle's value".
            fn = nil
            fn = lambda do |cycle_index, guard = n|
              return [] if n <= 0
              return [] if guard <= 0

              idx = cycle_index % n
              if items[idx] == :_elongate
                fn.call(cycle_index - 1, guard - 1)
              else
                fns[idx].call(cycle_index)
              end
            end
            ast[:mult] ? multiply_events_fn(fn, ast[:mult]) : fn
          elsif ast[:atom]
            base = build_events_fn(process_atom(ast[:atom]))
            ast[:mult] ? multiply_events_fn(base, ast[:mult]) : base
          else
            ->(_cycle_index) { [] }
          end
        else
          ->(_cycle_index) { [Event.new(Rational(0, 1), Rational(1, 1), ast.to_s)] }
        end
      end

      def expand_replicate_step(ast)
        return [ast] unless ast.is_a?(Hash) && ast[:rep]

        rep = ast[:rep].to_i
        rep = 1 if rep <= 0
        base = ast.dup
        base.delete(:rep)
        Array.new(rep, base)
      end

      def steps_to_events_fn(steps)
        n = steps.length
        n = 1 if n <= 0
        step_len = Rational(1, n)

        base_fns = steps.map { |it| build_events_fn(it) }

        lambda do |cycle_index|
          events = []

          steps.each_with_index do |step_ast, i|
            start = i * step_len
            fin = (i + 1) * step_len

            if step_ast == :_elongate
              last = events.last
              events[-1] = Event.new(last.start_pos, fin, last.value) if last
              next
            end

            base_fns[i].call(cycle_index).each do |e|
              s = start + e.start_pos * step_len
              t = start + e.end_pos * step_len
              events << Event.new(s, t, e.value)
            end
          end

          events
        end
      end

      def multiply_events_fn(events_fn, mult)
        m = mult.to_i
        m = 1 if m <= 0
        lambda do |cycle_index|
          return events_fn.call(cycle_index) if m == 1

          # Strudel/Pattern.fast semantics:
          # A fast(m) cycle pulls content from the next m cycles of the source pattern
          # and compresses them into one cycle.
          scaled = []
          m.times do |i|
            base = events_fn.call(cycle_index * m + i)
            base.each do |e|
              s = (e.start_pos + i) / m
              t = (e.end_pos + i) / m
              scaled << Event.new(s, t, e.value)
            end
          end
          scaled
        end
      end

      def ast_to_pattern(ast)
        events_fn = build_events_fn(ast)

        Pattern.new do |state|
          state.span.span_cycles.flat_map do |subspan|
            cycle_start = subspan.begin_time.sam
            cycle_index = cycle_start.to_i

            events_fn.call(cycle_index).filter_map do |e|
              whole = TimeSpan.new(cycle_start + e.start_pos, cycle_start + e.end_pos)
              part = whole.intersection(subspan)
              next unless part

              Hap.new(whole, part, e.value)
            end
          end
        end
      end

      def process_atom(atom)
        case atom
        when Hash
          if atom[:name] && atom[:n]
            { s: atom[:name].to_s, n: atom[:n].to_s.to_i }
          elsif atom[:name]
            atom[:name].to_s
          else
            atom
          end
        else
          atom
        end
      end
    end
  end
end
