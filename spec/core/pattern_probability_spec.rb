# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Pattern do
  # Phase 2.5.1
  describe "#sometimes_by" do
    it "applies function to some events based on probability" do
      # With prob=1.0, all events should be transformed
      pattern = Strudel::Pattern.fastcat("a", "b", "c", "d")
        .sometimes_by(1.0) { |p| p.with_value { |v| v.upcase } }
      haps = pattern.query_arc(0, 1)

      haps.each { |h| assert_equal h.value, h.value.upcase }
    end

    it "applies function to no events with probability 0" do
      pattern = Strudel::Pattern.fastcat("a", "b", "c", "d")
        .sometimes_by(0.0) { |p| p.with_value { |v| v.upcase } }
      haps = pattern.query_arc(0, 1)

      haps.each { |h| assert_equal h.value, h.value.downcase }
    end
  end

  # Phase 2.5.2
  describe "#sometimes" do
    it "is sometimes_by(0.5)" do
      pattern = Strudel::Pattern.pure("a")
      assert pattern.respond_to?(:sometimes)
    end
  end

  describe "#often" do
    it "is sometimes_by(0.75)" do
      pattern = Strudel::Pattern.pure("a")
      assert pattern.respond_to?(:often)
    end
  end

  describe "#rarely" do
    it "is sometimes_by(0.25)" do
      pattern = Strudel::Pattern.pure("a")
      assert pattern.respond_to?(:rarely)
    end
  end

  describe "#almost_never" do
    it "is sometimes_by(0.1)" do
      pattern = Strudel::Pattern.pure("a")
      assert pattern.respond_to?(:almost_never)
    end

    it "has almostNever alias" do
      pattern = Strudel::Pattern.pure("a")
      assert pattern.respond_to?(:almostNever)
    end
  end

  describe "#almost_always" do
    it "is sometimes_by(0.9)" do
      pattern = Strudel::Pattern.pure("a")
      assert pattern.respond_to?(:almost_always)
    end

    it "has almostAlways alias" do
      pattern = Strudel::Pattern.pure("a")
      assert pattern.respond_to?(:almostAlways)
    end
  end

  # Phase 2.5.3
  describe "#degrade_by" do
    it "removes all events with amount 1.0" do
      pattern = Strudel::Pattern.fastcat("a", "b", "c", "d").degrade_by(1.0)
      haps = pattern.query_arc(0, 1)

      assert_empty haps
    end

    it "keeps all events with amount 0.0" do
      pattern = Strudel::Pattern.fastcat("a", "b", "c", "d").degrade_by(0.0)
      haps = pattern.query_arc(0, 1)

      assert_equal 4, haps.length
    end
  end

  describe "#degrade" do
    it "is degrade_by(0.5)" do
      pattern = Strudel::Pattern.pure("a")
      assert pattern.respond_to?(:degrade)
    end
  end
end
