# frozen_string_literal: true

require "parslet"

module Strudel
  module Mini
    # Mini-Notation文法パーサー
    class Grammar < Parslet::Parser
      # 空白
      rule(:space) { match('\s').repeat(1) }
      rule(:space?) { space.maybe }

      # アトム（サウンド名、ノート名を含む - シャープ/フラット対応）
      rule(:atom_char) { match('[a-zA-Z0-9_#]') }
      rule(:atom_name) { atom_char.repeat(1).as(:name) }

      # サンプル番号 (:n)
      rule(:sample_number) { str(":") >> match('[0-9]').repeat(1).as(:n) }

      # アトム（名前 + オプションのサンプル番号）
      rule(:atom) do
        (atom_name >> sample_number.maybe).as(:atom)
      end

      # 休符
      rule(:rest) { (str("~") | str("-")).as(:rest) }

      # 乗算 (*n)
      rule(:multiplier) { str("*") >> match('[0-9.]').repeat(1).as(:mult) }

      # 基本要素（アトム、休符、またはグループ）
      rule(:element) do
        (
          (atom | rest | group | angle_group) >> multiplier.maybe
        ).as(:element)
      end

      # 角括弧グループ [...]
      rule(:group) do
        str("[") >> space? >> pattern >> space? >> str("]")
      end

      # 山括弧グループ <...>（スローキャット）
      rule(:angle_group) do
        (str("<") >> space? >> sequence >> space? >> str(">")).as(:slowcat)
      end

      # シーケンス（スペース区切り）
      rule(:sequence) do
        (element >> (space >> element).repeat).as(:sequence)
      end

      # スタック（カンマ区切り）
      rule(:stack) do
        (sequence >> (space? >> str(",") >> space? >> sequence).repeat(1)).as(:stack)
      end

      # パターン（スタックまたはシーケンス）
      rule(:pattern) do
        stack | sequence
      end

      # ルート
      root(:pattern)
    end

    # AST変換器
    class Transform < Parslet::Transform
      # 休符
      rule(rest: simple(:_)) { nil }

      # アトム（名前のみ）
      rule(atom: { name: simple(:name) }) do
        name.to_s
      end

      # アトム（名前 + サンプル番号）
      rule(atom: { name: simple(:name), n: simple(:n) }) do
        { s: name.to_s, n: n.to_s.to_i }
      end

      # 要素（乗算なし）
      rule(element: subtree(:content)) do
        content
      end

      # 要素（乗算あり）
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

      # シーケンス
      rule(sequence: subtree(:items)) do
        items.is_a?(Array) ? { sequence: items } : items
      end

      # スタック
      rule(stack: subtree(:items)) do
        { stack: items.is_a?(Array) ? items : [items] }
      end

      # スローキャット
      rule(slowcat: { sequence: subtree(:items) }) do
        { slowcat: items.is_a?(Array) ? items : [items] }
      end
    end

    # パーサー本体
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
            # サンプル番号付きアトム
            Pattern.pure(ast)
          elsif ast[:sequence] && ast[:mult]
            # 乗算付きシーケンス（サブシーケンス）
            pattern = sequence_to_pattern(ast[:sequence])
            pattern.fast(ast[:mult])
          elsif ast[:sequence]
            sequence_to_pattern(ast[:sequence])
          elsif ast[:stack]
            stack_to_pattern(ast[:stack])
          elsif ast[:slowcat]
            slowcat_to_pattern(ast[:slowcat])
          elsif ast[:atom]
            # 乗算付きアトム
            pattern = ast_to_pattern(process_atom(ast[:atom]))
            ast[:mult] ? pattern.fast(ast[:mult]) : pattern
          elsif ast[:rest]
            # 乗算付き休符
            Pattern.silence
          elsif ast[:mult]
            # その他の乗算
            pattern = ast_to_pattern(ast.reject { |k, _| k == :mult })
            pattern.fast(ast[:mult])
          else
            Pattern.silence
          end
        when Array
          # 配列は暗黙のシーケンス
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
        # スタック内の各アイテムはシーケンスである可能性がある
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
