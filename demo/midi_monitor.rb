# frozen_string_literal: true

# MIDI CC monitor. Run with:
#   bundle exec ruby demo/midi_monitor.rb "IAC Driver Bus 1"
# Move any knob or fader on your controller and watch the CC number + value.
# Useful for discovering which knob is which CC before mapping them in pattern.rb.

require "unimidi"

device_name = ARGV[0] || UniMIDI::Input.all.first&.name
abort "No MIDI input available. Pass device name as arg." unless device_name

device = UniMIDI::Input.all.find { |d| d.name == device_name }
abort "Device not found: #{device_name}" unless device

device.open
puts "Listening on #{device_name}. Move any control. Ctrl+C to exit."

trap("INT") do
  device.close
  exit
end

loop do
  messages = device.gets
  next if messages.nil? || messages.empty?

  messages.each do |msg|
    data = msg[:data]
    next unless data && data.length >= 3

    status = data[0]
    next unless (status & 0xF0) == 0xB0  # CC only

    channel = (status & 0x0F) + 1
    cc_num  = data[1]
    value   = data[2]
    printf("ch %2d  CC %3d  value %3d  (%.3f)\n", channel, cc_num, value, value / 127.0)
  end
end
