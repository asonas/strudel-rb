#!/usr/bin/env ruby
# frozen_string_literal: true

# strudel-rb デモ: First Sounds
# https://strudel.cc/workshop/first-sounds/ を参考にしたデモ
#
# 使い方:
#   1. samples/ ディレクトリにWAVファイルを配置
#      samples/bd/0.wav  (バスドラム)
#      samples/sd/0.wav  (スネア)
#      samples/hh/0.wav  (ハイハット)
#   2. bundle exec ruby demo/first_sounds.rb

require_relative "../lib/strudel"

# Runnerを作成
runner = Strudel::Runner.new(cps: 0.5)

# シグナルハンドラ（Ctrl+Cで停止）
trap("INT") do
  puts "\nStopping..."
  runner.cleanup
  exit
end

puts "strudel-rb Demo: First Sounds"
puts "=============================="
puts ""
puts "Press Ctrl+C to stop"
puts ""

# パターンを作成して再生
# 基本的なドラムパターン: bd hh sd hh
pattern = runner.sound("bd hh sd hh")

puts "Playing: sound(\"bd hh sd hh\")"
puts ""
puts "1 cycle = 2 seconds (cps = 0.5)"
puts ""

runner.play(pattern)

# メインスレッドを維持
loop do
  sleep 1
end
