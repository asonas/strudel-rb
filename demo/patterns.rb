#!/usr/bin/env ruby
# frozen_string_literal: true

# strudel-rb デモ: 様々なパターン
#
# 使い方:
#   bundle exec ruby demo/patterns.rb

require_relative "../lib/strudel"

runner = Strudel::Runner.new(cps: 0.5)

trap("INT") do
  puts "\nStopping..."
  runner.cleanup
  exit
end

puts "strudel-rb Demo: Patterns"
puts "========================="
puts ""

# パターンの例
patterns = [
  # 基本シーケンス
  ['sound("bd hh sd hh")', runner.sound("bd hh sd hh")],

  # サブシーケンス
  ['sound("bd [hh hh] sd [hh bd]")', runner.sound("bd [hh hh] sd [hh bd]")],

  # 乗算（速度変更）
  ['sound("bd hh*2 sd hh*3")', runner.sound("bd hh*2 sd hh*3")],

  # 休符
  ['sound("bd - sd -")', runner.sound("bd - sd -")],

  # 並列（スタック）
  ['sound("bd sd, hh hh hh hh")', runner.sound("bd sd, hh hh hh hh")],
]

puts "Press Enter to switch to the next pattern, or Ctrl+C to quit"
puts ""

patterns.each_with_index do |(code, pattern), index|
  puts "[#{index + 1}/#{patterns.length}] #{code}"
  runner.play(pattern)

  print "Press Enter for next..."
  gets
  puts ""
end

puts "Demo complete!"
runner.cleanup
