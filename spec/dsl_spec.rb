# frozen_string_literal: true

require_relative "spec_helper"

describe Strudel::DSL do
  include Strudel::DSL

  describe "#note" do
    it "parses note names to MIDI numbers" do
      pattern = note("c4")
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal 60, haps.first.value[:note]
    end

    it "parses sharps and flats" do
      pattern = note("c#4 db4")
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.length
      assert_equal 61, haps[0].value[:note]
      assert_equal 61, haps[1].value[:note]
    end

    it "handles different octaves" do
      pattern = note("a3 a4 a5")
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.length
      assert_equal 57, haps[0].value[:note] # A3
      assert_equal 69, haps[1].value[:note] # A4 (concert pitch)
      assert_equal 81, haps[2].value[:note] # A5
    end

    it "passes through numeric values" do
      pattern = note("60 64 67")
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.length
      assert_equal 60, haps[0].value[:note]
      assert_equal 64, haps[1].value[:note]
      assert_equal 67, haps[2].value[:note]
    end
  end
end
