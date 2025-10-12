# frozen_string_literal: true

module Strudel
  module Theory
    module Scale
      SCALES = {
        "major" => [0, 2, 4, 5, 7, 9, 11],
        "minor" => [0, 2, 3, 5, 7, 8, 10],
        "dorian" => [0, 2, 3, 5, 7, 9, 10],
        "phrygian" => [0, 1, 3, 5, 7, 8, 10],
        "lydian" => [0, 2, 4, 6, 7, 9, 11],
        "mixolydian" => [0, 2, 4, 5, 7, 9, 10],
        "locrian" => [0, 1, 3, 5, 6, 8, 10],
        "chromatic" => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
        "pentatonic" => [0, 2, 4, 7, 9],
        "blues" => [0, 3, 5, 6, 7, 10],
        "wholetone" => [0, 2, 4, 6, 8, 10]
      }.freeze

      NOTE_MAP = {
        "c" => 0, "c#" => 1, "db" => 1,
        "d" => 2, "d#" => 3, "eb" => 3,
        "e" => 4,
        "f" => 5, "f#" => 6, "gb" => 6,
        "g" => 7, "g#" => 8, "ab" => 8,
        "a" => 9, "a#" => 10, "bb" => 10,
        "b" => 11
      }.freeze

      class << self
        def get(name)
          SCALES[name.to_s.downcase] || SCALES["major"]
        end

        def degree_to_semitone(degree, scale_name = "major")
          scale = get(scale_name)
          scale_length = scale.length

          if degree >= 0
            octave = degree / scale_length
            index = degree % scale_length
            octave * 12 + scale[index]
          else
            # Handle negative degrees
            abs_degree = degree.abs
            octave = (abs_degree - 1) / scale_length + 1
            index = scale_length - 1 - ((abs_degree - 1) % scale_length)
            -(octave * 12 - scale[index])
          end
        end

        def parse_scale_name(scale_spec)
          parts = scale_spec.to_s.downcase.split(":")
          return [0, "major"] if parts.empty?

          root_str = parts[0]
          scale_name = parts[1] || "major"

          root = if root_str.match?(/^\d+$/)
                   root_str.to_i
                 else
                   NOTE_MAP[root_str] || 0
                 end

          [root, scale_name]
        end
      end
    end
  end
end
