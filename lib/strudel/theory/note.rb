# frozen_string_literal: true

module Strudel
  module Theory
    module Note
      NOTE_NAMES = %w[c c# d d# e f f# g g# a a# b].freeze
      NOTE_MAP = {
        "c" => 0, "c#" => 1, "db" => 1,
        "d" => 2, "d#" => 3, "eb" => 3,
        "e" => 4, "fb" => 4, "e#" => 5,
        "f" => 5, "f#" => 6, "gb" => 6,
        "g" => 7, "g#" => 8, "ab" => 8,
        "a" => 9, "a#" => 10, "bb" => 10,
        "b" => 11, "cb" => 11, "b#" => 0
      }.freeze

      class << self
        def parse(note)
          return note.to_i if note.is_a?(Numeric)

          note_str = note.to_s.downcase

          # 数値文字列を直接変換
          return note_str.to_i if note_str.match?(/^-?\d+$/)

          match = note_str.match(/^([a-g][#b]?)(-?\d+)$/)
          return nil unless match

          note_name = match[1]
          octave = match[2].to_i

          semitone = NOTE_MAP[note_name]
          return nil unless semitone

          (octave + 1) * 12 + semitone
        end

        def to_name(midi_note)
          octave = (midi_note / 12) - 1
          semitone = midi_note % 12
          "#{NOTE_NAMES[semitone]}#{octave}"
        end
      end
    end
  end
end
