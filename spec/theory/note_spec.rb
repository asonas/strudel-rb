# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Theory::Note do
  describe ".parse" do
    it "parses C4 as MIDI 60" do
      assert_equal 60, Strudel::Theory::Note.parse("c4")
    end

    it "parses A4 as MIDI 69" do
      assert_equal 69, Strudel::Theory::Note.parse("a4")
    end

    it "parses C#4 as MIDI 61" do
      assert_equal 61, Strudel::Theory::Note.parse("c#4")
    end

    it "parses Db4 as MIDI 61" do
      assert_equal 61, Strudel::Theory::Note.parse("db4")
    end

    it "parses different octaves" do
      assert_equal 48, Strudel::Theory::Note.parse("c3")
      assert_equal 72, Strudel::Theory::Note.parse("c5")
      assert_equal 36, Strudel::Theory::Note.parse("c2")
    end

    it "is case insensitive" do
      assert_equal 60, Strudel::Theory::Note.parse("C4")
      assert_equal 61, Strudel::Theory::Note.parse("C#4")
    end

    it "returns integer if already a number" do
      assert_equal 60, Strudel::Theory::Note.parse(60)
    end
  end

  describe ".to_name" do
    it "converts MIDI 60 to c4" do
      assert_equal "c4", Strudel::Theory::Note.to_name(60)
    end

    it "converts MIDI 69 to a4" do
      assert_equal "a4", Strudel::Theory::Note.to_name(69)
    end

    it "converts MIDI 61 to c#4" do
      assert_equal "c#4", Strudel::Theory::Note.to_name(61)
    end
  end
end
