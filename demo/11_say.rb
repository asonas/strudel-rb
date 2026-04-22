# frozen_string_literal: true

require_relative "../lib/strudel"

include Strudel::DSL

Strudel.setcps(0.5)

runner = Strudel::Runner.new
puts "Say DSL demo. Triggers 'ruby kaigi' once per cycle for 10 seconds."
puts "Press Ctrl+C to stop early."

pattern = say("ruby kaigi", voice: "Kyoko").room(0.3).gain(0.8)
runner.play(pattern)

sleep 10
runner.stop
runner.cleanup
