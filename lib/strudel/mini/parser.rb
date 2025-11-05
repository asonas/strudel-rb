# frozen_string_literal: true

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

      # Multiplier (*n)
      rule(:multiplier) { str("*") >> match('[0-9.]').repeat(1).as(:mult) }

      # Basic element (atom, rest, or group)
      rule(:element) do
        (
          (atom | rest | group | angle_group) >> multiplier.maybe
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

      # Atom (name only)
      rule(atom: { name: simple(:name) }) do
        name.to_s
      end

      # Atom (name + sample number)
      rule(atom: { name: simple(:name), n: simple(:n) }) do
        { s: name.to_s, n: n.to_s.to_i }
      end

      # Element (without multiplier)
      rule(element: subtree(:content)) do
        content
      end

      # Element (with multiplier)
      rule(element: { atom: subtree(:atom_content), mult: simple(:mult) }) do
        { atom: atom_content, mult: mult.to_s.to_f }
      end

      rule(element: { rest: simple(:_), mult: simple(:mult) }) do
        { rest: nil, mult: mult.to_s.to_f }
      end

      rule(element: { sequence: subtree(:seq), mult: simple(:mult) }) do
        { sequence: seq, mult: mult.to_s.to_f }
      end

      rule(element: { slowcat: subtree(:cat) }) do
        { slowcat: cat }
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
      rule(slowcat: { sequence: subtree(:items) }) do
        { slowcat: items.is_a?(Array) ? items : [items] }
      end
    end

    # Parser implementation
    class Parser
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

      def ast_to_pattern(ast)
        case ast
        when String
          Pattern.pure(ast)
        when Hash
          if ast[:s]
            # Atom with sample number
            Pattern.pure(ast)
          elsif ast[:sequence] && ast[:mult]
            # Sequence with multiplier (sub-sequence)
            pattern = sequence_to_pattern(ast[:sequence])
            pattern.fast(ast[:mult])
          elsif ast[:sequence]
            sequence_to_pattern(ast[:sequence])
          elsif ast[:stack]
            stack_to_pattern(ast[:stack])
          elsif ast[:slowcat]
            slowcat_to_pattern(ast[:slowcat])
          elsif ast[:atom]
            # Atom with multiplier
            pattern = ast_to_pattern(process_atom(ast[:atom]))
            ast[:mult] ? pattern.fast(ast[:mult]) : pattern
          elsif ast[:rest]
            # Rest with multiplier
            Pattern.silence
          elsif ast[:mult]
            # Other multiplier cases
            pattern = ast_to_pattern(ast.reject { |k, _| k == :mult })
            pattern.fast(ast[:mult])
          else
            Pattern.silence
          end
        when Array
          # Array is an implicit sequence
          sequence_to_pattern(ast)
        when NilClass
          Pattern.silence
        else
          Pattern.pure(ast.to_s)
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

      def sequence_to_pattern(items)
        items = [items] unless items.is_a?(Array)
        patterns = items.map { |item| ast_to_pattern(item) }.compact
        patterns.empty? ? Pattern.silence : Pattern.fastcat(*patterns)
      end

      def stack_to_pattern(items)
        items = [items] unless items.is_a?(Array)
        # Each item in the stack may be a sequence
        patterns = items.map do |item|
          if item.is_a?(Hash) && item[:sequence]
            sequence_to_pattern(item[:sequence])
          else
            ast_to_pattern(item)
          end
        end.compact
        patterns.empty? ? Pattern.silence : Pattern.stack(*patterns)
      end

      def slowcat_to_pattern(items)
        items = [items] unless items.is_a?(Array)
        patterns = items.map { |item| ast_to_pattern(item) }.compact
        patterns.empty? ? Pattern.silence : Pattern.slowcat(*patterns)
      end
    end
  end
end
