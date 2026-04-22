# frozen_string_literal: true

# Smoke test for MIDI input. Run with:
#   bundle exec ruby demo/midi_cc.rb "IAC Driver Bus 1"
# Turn CC #7 on your controller and watch the printed value follow.

require_relative "../lib/strudel"

device_name = ARGV[0] || UniMIDI::Input.all.first&.name
abort "No MIDI input available. Pass device name as arg." unless device_name

puts "Opening #{device_name}..."
input = Strudel::Midi::Registry.open(device_name)

pattern = input.cc(7)
puts "Move CC#7 on your controller. Ctrl+C to exit."

loop do
  value = pattern.query_arc(0, 1).first.value
  printf("\rCC7: %.3f   ", value)
  sleep 0.05
end
