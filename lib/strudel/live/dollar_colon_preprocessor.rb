# frozen_string_literal: true

module Strudel
  module Live
    # Rewrites Strudel JS-style `$:` track shorthand into `track { ... }` /
    # `_track { ... }` Ruby DSL calls before evaluation. `$:` is `$LOAD_PATH`
    # at the Ruby parser level and cannot be redefined; this preprocessor runs
    # on the source string before `instance_eval`.
    #
    # See docs/superpowers/specs/2026-05-11-dollar-colon-notation-design.md.
    module DollarColonPreprocessor
      LINE_REGEX = /\A(\s*)(_?)\$:(\S*)\s+([A-Za-z_"(\[{].*)\z/
      IDENT_REGEX = /\A[A-Za-z_][A-Za-z0-9_]*\z/

      module_function

      def call(code)
        lines = code.split("\n", -1)
        out = []
        i = 0
        line_no = 1

        while i < lines.length
          line = lines[i]

          if comment_only?(line) || !(m = LINE_REGEX.match(line))
            out << line
            i += 1
            line_no += 1
            next
          end

          indent, mute, name, rest = m.captures

          if name != "" && !IDENT_REGEX.match?(name)
            warn "[DollarColonPreprocessor] line #{line_no}: invalid track name '#{name}' ignored"
            name = ""
          end

          track_call = build_track_call(mute, name)

          if rest.match?(/\Ado\b/)
            out << "#{indent}#{track_call} #{rest}"
            i += 1
            line_no += 1
          else
            cont = []
            j = i + 1
            while j < lines.length && lines[j].match?(/\A\s*\./)
              cont << lines[j]
              j += 1
            end

            if cont.empty?
              code_part, comment_part = split_trailing_comment(rest)
              out << assemble_single(indent, track_call, code_part, comment_part)
            else
              out << "#{indent}#{track_call} { #{rest}"
              cont[0..-2].each { |l| out << l }
              last = cont.last
              code_part, comment_part = split_trailing_comment(last)
              out << assemble_close(code_part, comment_part)
            end

            line_no += (j - i)
            i = j
          end
        end

        out.join("\n")
      end

      def comment_only?(line)
        stripped = line.lstrip
        stripped.start_with?("#")
      end

      def build_track_call(mute, name)
        base = mute == "_" ? "_track" : "track"
        name == "" ? base : "#{base}(:#{name})"
      end

      # Walks the line left-to-right, ignoring `#` chars that sit inside a
      # double-quoted string. Returns [code_part, comment_part_or_nil].
      def split_trailing_comment(text)
        in_string = false
        escape = false
        i = 0
        while i < text.length
          ch = text[i]
          if escape
            escape = false
          elsif ch == "\\"
            escape = true
          elsif ch == '"'
            in_string = !in_string
          elsif ch == "#" && !in_string
            code_part = text[0...i].rstrip
            comment_part = text[i..-1]
            return [code_part, comment_part]
          end
          i += 1
        end
        [text, nil]
      end

      def assemble_single(indent, track_call, code_part, comment_part)
        body = "#{track_call} { #{code_part} }"
        body = "#{body} #{comment_part}" if comment_part
        "#{indent}#{body}"
      end

      def assemble_close(code_part, comment_part)
        if comment_part
          "#{code_part} } #{comment_part}"
        else
          "#{code_part} }"
        end
      end

      private_class_method :comment_only?, :build_track_call, :split_trailing_comment,
                           :assemble_single, :assemble_close
    end
  end
end
