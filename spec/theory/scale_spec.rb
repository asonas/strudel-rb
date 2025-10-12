# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Theory::Scale do
  describe ".get" do
    it "returns major scale intervals" do
      scale = Strudel::Theory::Scale.get("major")

      assert_equal [0, 2, 4, 5, 7, 9, 11], scale
    end

    it "returns minor scale intervals" do
      scale = Strudel::Theory::Scale.get("minor")

      assert_equal [0, 2, 3, 5, 7, 8, 10], scale
    end

    it "returns chromatic scale" do
      scale = Strudel::Theory::Scale.get("chromatic")

      assert_equal [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], scale
    end
  end

  describe ".degree_to_semitone" do
    it "converts scale degree to semitone in major scale" do
      # C major: C D E F G A B
      assert_equal 0, Strudel::Theory::Scale.degree_to_semitone(0, "major")
      assert_equal 2, Strudel::Theory::Scale.degree_to_semitone(1, "major")
      assert_equal 4, Strudel::Theory::Scale.degree_to_semitone(2, "major")
      assert_equal 5, Strudel::Theory::Scale.degree_to_semitone(3, "major")
      assert_equal 7, Strudel::Theory::Scale.degree_to_semitone(4, "major")
    end

    it "wraps around octaves" do
      # Degree 7 in major = octave above root
      assert_equal 12, Strudel::Theory::Scale.degree_to_semitone(7, "major")
      # Degree 8 = second note of next octave
      assert_equal 14, Strudel::Theory::Scale.degree_to_semitone(8, "major")
    end

    it "handles negative degrees" do
      assert_equal(-1, Strudel::Theory::Scale.degree_to_semitone(-1, "major"))
      assert_equal(-12, Strudel::Theory::Scale.degree_to_semitone(-7, "major"))
    end
  end

  describe ".parse_scale_name" do
    it "parses root:scale format" do
      root, scale = Strudel::Theory::Scale.parse_scale_name("c:major")

      assert_equal 0, root
      assert_equal "major", scale
    end

    it "parses number:scale format" do
      root, scale = Strudel::Theory::Scale.parse_scale_name("9:minor")

      assert_equal 9, root
      assert_equal "minor", scale
    end

    it "parses note name with sharp" do
      root, scale = Strudel::Theory::Scale.parse_scale_name("f#:minor")

      assert_equal 6, root
      assert_equal "minor", scale
    end
  end
end
