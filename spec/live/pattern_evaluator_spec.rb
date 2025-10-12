# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/strudel/live/pattern_evaluator"

describe Strudel::Live::PatternEvaluator do
  def evaluator
    @evaluator ||= Strudel::Live::PatternEvaluator.new
  end

  describe "#evaluate_string" do
    it "returns a Pattern from sound DSL" do
      result = evaluator.evaluate_string('sound("bd")')

      assert_instance_of Strudel::Pattern, result
    end

    it "can use stack DSL method" do
      result = evaluator.evaluate_string('stack(sound("bd"), sound("hh"))')

      assert_instance_of Strudel::Pattern, result
      haps = result.query_arc(0, 1)
      values = haps.map { |h| h.value[:s] }
      assert_includes values, "bd"
      assert_includes values, "hh"
    end

    it "raises SyntaxError for invalid Ruby syntax" do
      assert_raises(SyntaxError) do
        evaluator.evaluate_string('sound("bd"')
      end
    end

    it "raises RuntimeError for invalid Mini-Notation" do
      assert_raises(RuntimeError) do
        evaluator.evaluate_string('sound("[[[[")')
      end
    end
  end

  describe "#evaluate_file" do
    it "reads and evaluates a file" do
      # 一時ファイルを作成
      require "tempfile"
      file = Tempfile.new(["pattern", ".rb"])
      file.write('sound("bd hh sd hh")')
      file.close

      result = evaluator.evaluate_file(file.path)

      assert_instance_of Strudel::Pattern, result
      haps = result.query_arc(0, 1)
      assert_equal 4, haps.length
    ensure
      file&.unlink
    end

    it "raises Errno::ENOENT for non-existent file" do
      assert_raises(Errno::ENOENT) do
        evaluator.evaluate_file("/non/existent/file.rb")
      end
    end
  end
end
