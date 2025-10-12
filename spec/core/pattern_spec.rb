# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Pattern do
  describe ".pure" do
    it "creates a pattern that produces one hap per cycle" do
      pattern = Strudel::Pattern.pure("bd")
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal "bd", haps.first.value
      assert_equal Strudel::TimeSpan.new(0, 1), haps.first.whole
    end

    it "produces multiple haps when spanning multiple cycles" do
      pattern = Strudel::Pattern.pure("bd")
      haps = pattern.query_arc(0, 2)

      assert_equal 2, haps.length
      assert_equal Strudel::TimeSpan.new(0, 1), haps[0].whole
      assert_equal Strudel::TimeSpan.new(1, 2), haps[1].whole
    end

    it "produces partial hap when query spans partial cycle" do
      pattern = Strudel::Pattern.pure("bd")
      haps = pattern.query_arc(Rational(1, 4), Rational(3, 4))

      assert_equal 1, haps.length
      assert_equal Strudel::TimeSpan.new(0, 1), haps.first.whole
      assert_equal Strudel::TimeSpan.new(Rational(1, 4), Rational(3, 4)), haps.first.part
    end
  end

  describe ".silence" do
    it "creates a pattern that produces no haps" do
      pattern = Strudel::Pattern.silence
      haps = pattern.query_arc(0, 1)

      assert_empty haps
    end
  end

  describe ".fastcat" do
    it "sequences patterns within a cycle" do
      pattern = Strudel::Pattern.fastcat(
        Strudel::Pattern.pure("bd"),
        Strudel::Pattern.pure("sd")
      )
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "sd", haps[1].value
      assert_equal Strudel::TimeSpan.new(0, Rational(1, 2)), haps[0].whole
      assert_equal Strudel::TimeSpan.new(Rational(1, 2), 1), haps[1].whole
    end

    it "sequences four patterns" do
      pattern = Strudel::Pattern.fastcat(
        Strudel::Pattern.pure("bd"),
        Strudel::Pattern.pure("hh"),
        Strudel::Pattern.pure("sd"),
        Strudel::Pattern.pure("hh")
      )
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "hh", haps[1].value
      assert_equal "sd", haps[2].value
      assert_equal "hh", haps[3].value
    end

    it "accepts string values and auto-converts to patterns" do
      pattern = Strudel::Pattern.fastcat("bd", "sd")
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal "bd", haps[0].value
      assert_equal "sd", haps[1].value
    end
  end

  describe ".stack" do
    it "plays patterns in parallel" do
      pattern = Strudel::Pattern.stack(
        Strudel::Pattern.pure("bd"),
        Strudel::Pattern.pure("hh")
      )
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      values = haps.map(&:value)
      assert_includes values, "bd"
      assert_includes values, "hh"
    end
  end

  describe ".slowcat" do
    it "plays one pattern per cycle" do
      pattern = Strudel::Pattern.slowcat(
        Strudel::Pattern.pure("bd"),
        Strudel::Pattern.pure("sd")
      )

      haps0 = pattern.query_arc(0, 1)
      assert_equal 1, haps0.length
      assert_equal "bd", haps0.first.value

      haps1 = pattern.query_arc(1, 2)
      assert_equal 1, haps1.length
      assert_equal "sd", haps1.first.value

      # Cycles back
      haps2 = pattern.query_arc(2, 3)
      assert_equal 1, haps2.length
      assert_equal "bd", haps2.first.value
    end
  end

  describe "#fast" do
    it "speeds up the pattern" do
      pattern = Strudel::Pattern.pure("bd").fast(2)
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal Strudel::TimeSpan.new(0, Rational(1, 2)), haps[0].whole
      assert_equal Strudel::TimeSpan.new(Rational(1, 2), 1), haps[1].whole
    end
  end

  describe "#slow" do
    it "slows down the pattern" do
      pattern = Strudel::Pattern.pure("bd").slow(2)
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal Strudel::TimeSpan.new(0, 2), haps.first.whole
      assert_equal Strudel::TimeSpan.new(0, 1), haps.first.part
    end

    it "plays full hap in second cycle" do
      pattern = Strudel::Pattern.pure("bd").slow(2)
      haps = pattern.query_arc(0, 2)

      assert_equal 1, haps.length
      assert_equal Strudel::TimeSpan.new(0, 2), haps.first.whole
      assert_equal Strudel::TimeSpan.new(0, 2), haps.first.part
    end
  end

  describe "#with_value" do
    it "transforms values in the pattern" do
      pattern = Strudel::Pattern.pure("bd").with_value { |v| { s: v } }
      haps = pattern.query_arc(0, 1)

      assert_equal({ s: "bd" }, haps.first.value)
    end
  end

  describe "#filter_haps" do
    it "filters haps based on predicate" do
      pattern = Strudel::Pattern.fastcat("bd", "sd", "hh")
        .filter_haps { |h| h.value != "sd" }
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      values = haps.map(&:value)
      refute_includes values, "sd"
    end
  end

  describe "#onsets_only" do
    it "filters to only haps with onset" do
      pattern = Strudel::Pattern.pure("bd").slow(2)

      # Query second half of the span
      all_haps = pattern.query_arc(Rational(1, 2), Rational(3, 2))
      onset_haps = pattern.onsets_only.query_arc(Rational(1, 2), Rational(3, 2))

      # There's one hap but it doesn't have onset at 0.5
      assert_equal 1, all_haps.length
      refute all_haps.first.has_onset?
      assert_empty onset_haps
    end
  end

  describe "#add" do
    it "adds a number to pattern values" do
      pattern = Strudel::Pattern.pure(3).add(2)
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal 5, haps.first.value
    end

    it "adds two patterns together" do
      pattern = Strudel::Pattern.pure(3).add(Strudel::Pattern.pure(2))
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal 5, haps.first.value
    end

    it "adds patterns with different timings" do
      # 3 for full cycle, add sequence of 1, 2
      pattern = Strudel::Pattern.pure(3).add(
        Strudel::Pattern.fastcat(
          Strudel::Pattern.pure(1),
          Strudel::Pattern.pure(2)
        )
      )
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal 4, haps[0].value # 3 + 1
      assert_equal 5, haps[1].value # 3 + 2
    end
  end

  describe "#sub" do
    it "subtracts a number from pattern values" do
      pattern = Strudel::Pattern.pure(5).sub(2)
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal 3, haps.first.value
    end
  end

  describe "#mul" do
    it "multiplies pattern values" do
      pattern = Strudel::Pattern.pure(3).mul(4)
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal 12, haps.first.value
    end
  end

  describe "#div" do
    it "divides pattern values" do
      pattern = Strudel::Pattern.pure(12).div(3)
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal 4, haps.first.value
    end
  end

  describe "#rev" do
    it "reverses the pattern within each cycle" do
      pattern = Strudel::Pattern.fastcat(
        Strudel::Pattern.pure("a"),
        Strudel::Pattern.pure("b"),
        Strudel::Pattern.pure("c"),
        Strudel::Pattern.pure("d")
      ).rev
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
      assert_equal "d", haps[0].value
      assert_equal "c", haps[1].value
      assert_equal "b", haps[2].value
      assert_equal "a", haps[3].value
    end
  end

  describe "#every" do
    it "applies function every n cycles" do
      pattern = Strudel::Pattern.pure("a").every(2) { |p| p.with_value { |v| v.upcase } }

      # Cycle 0: no transformation
      haps0 = pattern.query_arc(0, 1)
      assert_equal "a", haps0.first.value

      # Cycle 1: transformation applied
      haps1 = pattern.query_arc(1, 2)
      assert_equal "A", haps1.first.value

      # Cycle 2: no transformation
      haps2 = pattern.query_arc(2, 3)
      assert_equal "a", haps2.first.value

      # Cycle 3: transformation applied
      haps3 = pattern.query_arc(3, 4)
      assert_equal "A", haps3.first.value
    end
  end

  describe "#fit" do
    it "adds unit and speed to make sample fit the cycle" do
      pattern = Strudel::Pattern.pure({ s: "breaks" }).fit
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal "c", haps.first.value[:unit]
      assert_equal 1.0, haps.first.value[:speed]
    end

    it "adjusts speed based on hap duration" do
      # Two haps per cycle = each hap is 0.5 cycles
      pattern = Strudel::Pattern.fastcat(
        Strudel::Pattern.pure({ s: "breaks" }),
        Strudel::Pattern.pure({ s: "breaks" })
      ).fit
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      # Each hap is 0.5 cycles, so speed should be 2.0 to fit
      assert_equal 2.0, haps[0].value[:speed]
      assert_equal 2.0, haps[1].value[:speed]
    end
  end

  describe "#trans" do
    it "transposes note values by semitones" do
      pattern = Strudel::Pattern.pure({ note: 60 }).trans(12)
      haps = pattern.query_arc(0, 1)

      assert_equal 72, haps.first.value[:note]
    end

    it "transposes negative semitones" do
      pattern = Strudel::Pattern.pure({ note: 60 }).trans(-12)
      haps = pattern.query_arc(0, 1)

      assert_equal 48, haps.first.value[:note]
    end

    it "uses pattern for transposition amount" do
      pattern = Strudel::Pattern.pure({ note: 60 }).trans(
        Strudel::Pattern.fastcat(
          Strudel::Pattern.pure(0),
          Strudel::Pattern.pure(7)
        )
      )
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal 60, haps[0].value[:note]
      assert_equal 67, haps[1].value[:note]
    end
  end

  describe "#scale" do
    it "converts scale degrees to notes" do
      # Degree 0, 1, 2 in C major = C, D, E (MIDI 60, 62, 64)
      pattern = Strudel::Pattern.fastcat(
        Strudel::Pattern.pure(0),
        Strudel::Pattern.pure(1),
        Strudel::Pattern.pure(2)
      ).scale("c:major")
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.length
      assert_equal 60, haps[0].value[:note]
      assert_equal 62, haps[1].value[:note]
      assert_equal 64, haps[2].value[:note]
    end

    it "handles different root notes" do
      # Degree 0 in A minor (A = 9 semitones from C)
      # A4 = MIDI 69
      pattern = Strudel::Pattern.pure(0).scale("a:minor")
      haps = pattern.query_arc(0, 1)

      assert_equal 69, haps.first.value[:note]
    end

    it "handles numeric root" do
      # Root 9 = A
      pattern = Strudel::Pattern.pure(0).scale("9:minor")
      haps = pattern.query_arc(0, 1)

      assert_equal 69, haps.first.value[:note]
    end
  end
end
