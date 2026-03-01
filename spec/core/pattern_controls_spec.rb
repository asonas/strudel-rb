# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Pattern do
  # Phase 1.1
  describe "#room" do
    it "sets room control on pattern" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).room(0.5)
      haps = pattern.query_arc(0, 1)

      assert_equal 1, haps.length
      assert_equal 0.5, haps.first.value[:room]
    end
  end

  # Phase 1.2
  describe "#roomsize" do
    it "sets roomsize control on pattern" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).roomsize(3)
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.first.value[:roomsize]
    end

    it "has rsize alias" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).rsize(3)
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.first.value[:roomsize]
    end

    it "has sz alias" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).sz(3)
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.first.value[:roomsize]
    end

    it "has size alias" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).size(3)
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.first.value[:roomsize]
    end
  end

  # Phase 1.3
  describe "#oct" do
    it "transposes notes by octaves" do
      pattern = Strudel::Pattern.pure({ note: 60 }).oct(2)
      haps = pattern.query_arc(0, 1)

      assert_equal 84, haps.first.value[:note] # 60 + 24
    end

    it "oct(0) is a no-op" do
      pattern = Strudel::Pattern.pure({ note: 60 }).oct(0)
      haps = pattern.query_arc(0, 1)

      assert_equal 60, haps.first.value[:note]
    end

    it "handles negative octaves" do
      pattern = Strudel::Pattern.pure({ note: 60 }).oct(-1)
      haps = pattern.query_arc(0, 1)

      assert_equal 48, haps.first.value[:note] # 60 - 12
    end
  end

  # Phase 1.4
  describe "#transpose" do
    it "transposes notes by semitones (alias for trans)" do
      pattern = Strudel::Pattern.pure({ note: 60 }).transpose(12)
      haps = pattern.query_arc(0, 1)

      assert_equal 72, haps.first.value[:note]
    end
  end

  # Phase 1.5
  describe "#clip" do
    it "sets clip control on pattern" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).clip(0.7)
      haps = pattern.query_arc(0, 1)

      assert_equal 0.7, haps.first.value[:clip]
    end
  end

  # Phase 1.6.1
  describe "#distort" do
    it "sets distort control on pattern" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).distort(5)
      haps = pattern.query_arc(0, 1)

      assert_equal 5, haps.first.value[:distort]
    end

    it "has dist alias" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).dist(5)
      haps = pattern.query_arc(0, 1)

      assert_equal 5, haps.first.value[:distort]
    end
  end

  # Phase 1.6.2
  describe "#distorttype" do
    it "sets distorttype control on pattern" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).distorttype("sinefold")
      haps = pattern.query_arc(0, 1)

      assert_equal "sinefold", haps.first.value[:distorttype]
    end
  end

  # Phase 1.6.3
  describe "#sinefold" do
    it "sets distort and distorttype to sinefold" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).sinefold(3)
      haps = pattern.query_arc(0, 1)

      assert_equal 3, haps.first.value[:distort]
      assert_equal "sinefold", haps.first.value[:distorttype]
    end
  end

  # Phase 1.6.4
  describe "#fold" do
    it "sets distort and distorttype to fold" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).fold(2)
      haps = pattern.query_arc(0, 1)

      assert_equal 2, haps.first.value[:distort]
      assert_equal "fold", haps.first.value[:distorttype]
    end
  end

  # Phase 1.6.5
  describe "#diode" do
    it "sets distort and distorttype to diode" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).diode(4)
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.first.value[:distort]
      assert_equal "diode", haps.first.value[:distorttype]
    end
  end

  # Phase 1.6.6
  describe "#distortvol" do
    it "sets distortvol control on pattern" do
      pattern = Strudel::Pattern.pure({ s: "bd" }).distortvol(0.8)
      haps = pattern.query_arc(0, 1)

      assert_equal 0.8, haps.first.value[:distortvol]
    end
  end
end
